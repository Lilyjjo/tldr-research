use std::{
    collections::HashMap,
    str::FromStr,
};

use alloy::{
    consensus::TxEnvelope,
    eips::eip2718::Encodable2718,
    network::{
        Ethereum,
        EthereumSigner,
        NetworkSigner,
        TransactionBuilder,
    },
    providers::{
        layers::SignerProvider,
        Provider,
        ProviderBuilder,
        RootProvider,
    },
    rpc::types::eth::{
        TransactionInput,
        TransactionRequest,
    },
    signers::{
        k256::elliptic_curve::consts::U24,
        wallet::LocalWallet,
        Signer,
    },
    transports::http::Http,
};
use alloy_primitives::{
    Address,
    Bytes,
    FixedBytes,
    B256,
    U16,
    U160,
    U256,
    U64,
};
use alloy_rlp::{
    BufMut,
    Encodable,
};
use alloy_sol_types::{
    sol,
    SolCall,
    SolStruct,
    SolValue,
};
use color_eyre::{
    eyre,
    eyre::{
        ensure,
        eyre,
        Context,
    },
};
use eyre::ContextCompat;
use reqwest;

use crate::suave_network::{
    ConfidentialComputeRecord,
    ConfidentialComputeRequest,
    SuaveNetwork,
    SuaveSigner,
};

sol! {
    #[derive(Debug, PartialEq)]
    interface IAMMAuctionSuapp {
        function newPendingTxn() external returns (bytes memory);
        function newBid(string memory salt) external returns (bytes memory);
        function runAuction() external returns (bytes memory);
        function setSigningKey(uint256 keyNonce) external returns (bytes memory);
        function setSepoliaUrl() external returns (bytes memory);
        function initLastL1Block() external returns (bytes memory);

        struct Bid {
            address bidder;
            uint256 blockNumber;
            uint256 payment;
            bytes swapTxn;
            uint8 v;
            bytes32 r;
            bytes32 s;
        }
    }

    struct withdrawBid{
        address bidder;
        uint256 blockNumber;
        uint256 amount;
    }

    #[derive(Debug, PartialEq)]
    interface ISwapRouter {
        function exactInputSingle(
            ExactInputSingleParams calldata params
        ) external payable returns (uint256 amountOut);

        struct ExactInputSingleParams {
            address tokenIn;
            address tokenOut;
            uint24 fee;
            address recipient;
            uint256 deadline;
            uint256 amountIn;
            uint256 amountOutMinimum;
            uint160 sqrtPriceLimitX96;
        }
    }
}

pub struct AmmAuctionSuapp {
    auction_suapp_address: Address,
    deposit_contract_address: Address,
    pool_address: Address,
    token_0_address: Address,
    token_1_address: Address,
    swap_router_address: Address,
    execution_node: Address,
    suave_provider: RootProvider<Http<reqwest::Client>>,
    sepolia_provider: RootProvider<Http<reqwest::Client>>,
    suave_signer: SignerProvider<
        Http<reqwest::Client>,
        RootProvider<Http<reqwest::Client>, SuaveNetwork>,
        SuaveSigner,
        SuaveNetwork,
    >,
    sepolia_wallets: HashMap<String, LocalWallet>,
    sepolia_rpc: String,
    last_used_suave_nonce: u128,
}

// send(to contract (on network), from entity)
// contracts (with networks), sent to functions from entities
impl AmmAuctionSuapp {
    pub async fn new(
        auction_suapp_address: String,
        deposit_contract_address: String,
        pool_address: String,
        token_0_address: String,
        token_1_address: String,
        swap_router_address: String,
        execution_node: String,
        suave_rpc: String,
        sepolia_rpc: String,
        sepolia_eoas: &HashMap<String, (String, String)>,
    ) -> eyre::Result<Self> {
        // build strings
        let auction_suapp_address = Address::from_str(&auction_suapp_address)
            .wrap_err("failed to parse suapp amm address")?;
        let deposit_contract_address = Address::from_str(&deposit_contract_address)
            .wrap_err("failed to parse deposit contract address")?;
        let pool_address = Address::from_str(&pool_address).wrap_err("failed to pool_address")?;
        let token_0_address =
            Address::from_str(&token_0_address).wrap_err("failed to parse token_0_address")?;
        let token_1_address =
            Address::from_str(&token_1_address).wrap_err("failed to parse token_1_address")?;
        let swap_router_address = Address::from_str(&swap_router_address)
            .wrap_err("failed to parse swap_router_address")?;
        let execution_node =
            Address::from_str(&execution_node).wrap_err("failed to parse execution_node")?;

        // build sepolia provider
        let sepolia_rpc_url =
            url::Url::parse(&sepolia_rpc).wrap_err("failed to build url from suave rpc string")?;
        let sepolia_provider = ProviderBuilder::new()
            .on_reqwest_http(sepolia_rpc_url.clone())
            .wrap_err("failed to build provider from given rpc url")?;

        // build suave eth provider (doesn't do CCRs but can do non CCR queries, todo if this is
        // needed)
        let suave_rpc_url =
            url::Url::parse(&suave_rpc).wrap_err("failed to build url from suave rpc string")?;
        let suave_provider = ProviderBuilder::new()
            .on_reqwest_http(suave_rpc_url.clone())
            .wrap_err("failed to build provider from given rpc url")?;

        // build suave signer provider
        let suave_wallet: LocalWallet = sepolia_eoas
            .get("funded_suave")
            .context("missing funded_suave eoa in sepolia_eoas")?
            .1
            .parse()
            .wrap_err("failed to parse pk for funded_suave")?;
        let suave_signer = ProviderBuilder::<_, SuaveNetwork>::default()
            .signer(SuaveSigner::from(suave_wallet))
            .on_reqwest_http(suave_rpc_url.clone())
            .wrap_err("failed to build suave_signer provider")?;

        // build other eoa wallets
        let mut sepolia_wallets = HashMap::new();
        for sepolia_eoa in sepolia_eoas {
            let wallet: LocalWallet = sepolia_eoa
                .1
                .1
                .parse()
                .wrap_err("failed to parse pk for sepolia wallet")?;
            // maybe idk
            // let signer_provider = ProviderBuilder::<_, SuaveNetwork>::default()
            // .signer(SuaveSigner::from(wallet))
            // .on_reqwest_http(suave_rpc_url.clone())
            // .context("failed to build signer wallet")?;
            sepolia_wallets.insert(sepolia_eoa.0.to_string(), wallet);
        }
        Ok(AmmAuctionSuapp {
            auction_suapp_address,
            deposit_contract_address,
            pool_address,
            token_0_address,
            token_1_address,
            swap_router_address,
            execution_node,
            suave_provider,
            sepolia_provider,
            suave_signer,
            sepolia_wallets,
            sepolia_rpc,
            last_used_suave_nonce: 0,
        })
    }

    pub async fn send_ccr(
        &self,
        confidential_compute_request: ConfidentialComputeRequest,
    ) -> eyre::Result<()> {
        // TODO add better error handling, maybe even skipping getting response?
        println!("sending ccr");
        let result = self
            .suave_signer
            .send_transaction(confidential_compute_request)
            .await
            .context("failed to send ccr")?;
        let tx_hash = B256::from_slice(&result.tx_hash().to_vec());
        println!("retrieving response");
        let tx_response = self
            .suave_signer
            .get_transaction_by_hash(tx_hash)
            .await
            .unwrap();
        println!("{:#?}", tx_response);
        Ok(())
    }

    pub async fn build_generic_suave_transaction(
        &mut self,
        signer: Address,
    ) -> eyre::Result<TransactionRequest> {
        // gather network dependent variables
        let mut nonce = self
            .suave_provider
            .get_transaction_count(signer, None)
            .await
            .context("failed to get transaction count for address")?;

        // nonce management for sending CCRs without waiting for others to complete
        if self.last_used_suave_nonce >= nonce.to::<u128>() {
            nonce = U64::from(self.last_used_suave_nonce + 1);
        }
        self.last_used_suave_nonce = nonce.to::<u128>();

        let gas_price = self
            .suave_provider
            .get_gas_price()
            .await
            .context("failed to get gas price")?
            .wrapping_add(U256::from(10));

        let gas = 0x0f4240; // TODO: figure out what is reasonable, probably should be per function

        let chain_id = self
            .suave_provider
            .get_chain_id()
            .await
            .context("failed to get chain id")?;

        let tx = TransactionRequest::default()
            .to(Some(self.auction_suapp_address))
            .gas_limit(U256::from(gas))
            .with_gas_price(gas_price)
            .with_chain_id(chain_id.to::<u64>())
            .with_nonce(nonce.to::<u64>());
        Ok(tx)
    }

    pub async fn build_generic_sepolia_transaction(
        &self,
        signer: Address,
        target_contract: Address,
    ) -> eyre::Result<TransactionRequest> {
        // gather network dependent variables
        let nonce = self
            .sepolia_provider
            .get_transaction_count(signer, None)
            .await
            .context("failed to get transaction count for address")?;

        let gas_price = self
            .sepolia_provider
            .get_gas_price()
            .await
            .context("failed to get gas price")?
            .wrapping_add(U256::from(10)); // to account for gas fluction between creation and sending

        let gas = 0x0f4240; // TODO: figure out what is reasonable, probably should be per function

        let chain_id = self
            .sepolia_provider
            .get_chain_id()
            .await
            .context("failed to get chain id")?;

        let tx = TransactionRequest::default()
            .to(Some(target_contract))
            .gas_limit(U256::from(gas))
            .with_gas_price(gas_price)
            .with_chain_id(chain_id.to::<u64>())
            .with_nonce(nonce.to::<u64>());
        Ok(tx)
    }

    pub async fn new_pending_txn(
        &mut self,
        swapper: &String,
        signed_txn: Bytes,
    ) -> eyre::Result<()> {
        let swapper = self
            .sepolia_wallets
            .get(swapper)
            .expect("swapper's wallet not initialized");
        let suave_signer = self
            .sepolia_wallets
            .get("funded_suave")
            .expect("funded suave's wallet not initialized");
        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAMMAuctionSuapp::newPendingTxnCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node);
        self.send_ccr(ConfidentialComputeRequest::new(cc_record, signed_txn))
            .await
            .wrap_err("failed to send swap CCR")?;
        Ok(())
    }

    pub async fn new_bid(
        &mut self,
        bidder: &String,
        block_number: u128,
        bid_amount: u128,
        in_amount: u128,
        token_0_in: bool,
    ) -> eyre::Result<()> {
        // grab bidder and suave signer
        let bidder = self
            .sepolia_wallets
            .get(bidder)
            .expect("bidders's wallet not initialized");
        let suave_signer = self
            .sepolia_wallets
            .get("funded_suave")
            .expect("funded suave's wallet not initialized");

        // create swap router transaction input
        let (token_in, token_out) = if token_0_in {
            (self.token_0_address, self.token_1_address)
        } else {
            (self.token_1_address, self.token_0_address)
        };

        let swap_input_params = ISwapRouter::ExactInputSingleParams {
            tokenIn: token_in,
            tokenOut: token_out,
            fee: 3000u32,
            recipient: bidder.address(),
            deadline: U256::from(1776038248), // 4/12/2026
            amountIn: U256::from(in_amount),
            amountOutMinimum: U256::from(1),
            sqrtPriceLimitX96: U256::from(0),
        };

        // create and sign over the swap transaction
        let mut rlp_encoded_swap_tx = Vec::new();
        self.build_generic_sepolia_transaction(bidder.address(), self.swap_router_address)
            .await
            .wrap_err("failed to build generic sepolia transaction")?
            .input(TransactionInput::new(
                ISwapRouter::exactInputSingleCall {
                    params: swap_input_params,
                }
                .abi_encode()
                .into(),
            ))
            .build(&EthereumSigner::from(bidder.clone()))
            .await
            .wrap_err("failed to sign transaction")?
            .encode_2718(&mut rlp_encoded_swap_tx);

        // create and sign over withdraw 712 request
        let my_domain = alloy_sol_types::eip712_domain!(
            name: "AuctionDeposits",
            version: "1",
            chain_id: 11155111u64,
            verifying_contract: self.deposit_contract_address,
        );

        let bid_request = withdrawBid {
            bidder: bidder.address(),
            blockNumber: U256::from(block_number),
            amount: U256::from(bid_amount),
        };

        let bid_signing_hash = bid_request.eip712_signing_hash(&my_domain);
        let bid_signature = bidder
            .sign_hash(&bid_signing_hash)
            .await
            .wrap_err("failed to sign bid EIP712 hash")?;

        // create bid input
        let bid = IAMMAuctionSuapp::Bid {
            bidder: bidder.address(),
            blockNumber: U256::from(block_number),
            payment: U256::from(bid_amount),
            swapTxn: rlp_encoded_swap_tx.into(),
            v: bid_signature.v().y_parity_byte(),
            r: bid_signature.r().into(),
            s: bid_signature.r().into(),
        }
        .abi_encode();

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .wrap_err("failed to build generic suave transaction")?
            .input(
                Bytes::from(
                    IAMMAuctionSuapp::newBidCall {
                        salt: "111".to_string(),
                    }
                    .abi_encode(),
                )
                .into(),
            );

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node);
        self.send_ccr(ConfidentialComputeRequest::new(cc_record, bid.into()))
            .await
            .wrap_err("failed to send bid CCR")?;
        Ok(())
    }

    pub async fn initialize_l1_block(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .sepolia_wallets
            .get("funded_suave")
            .expect("funded suave's wallet not initialized");

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAMMAuctionSuapp::initLastL1BlockCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node);
        self.send_ccr(ConfidentialComputeRequest::new(cc_record, Bytes::new()))
            .await
            .wrap_err("failed to send L1 block init CCR")?;
        Ok(())
    }

    pub async fn set_sepolia_url(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .sepolia_wallets
            .get("funded_suave")
            .expect("funded suave's wallet not initialized");

        let mut confidential_inputs = Vec::new();
        self.sepolia_rpc.encode(&mut confidential_inputs);

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAMMAuctionSuapp::setSepoliaUrlCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node);
        self.send_ccr(ConfidentialComputeRequest::new(
            cc_record,
            confidential_inputs.into(),
        ))
        .await
        .wrap_err("failed to send sepolia init CCR")?;
        Ok(())
    }

    pub async fn set_signing_key(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .sepolia_wallets
            .get("funded_suave")
            .expect("funded suave's wallet not initialized");

        let suave_stored_wallet = self
            .sepolia_wallets
            .get("suapp_signing_key")
            .expect("suapp's signing wallet not initialized");
        // caching so we can borrow as mutable later
        let suave_stored_wallet_pk = suave_stored_wallet.signer().to_bytes().abi_encode();

        // get sepolia nonce for the key we're storing in the suapp
        let nonce = self
            .sepolia_provider
            .get_transaction_count(suave_stored_wallet.address(), None)
            .await
            .context("failed to get transaction count for suapp stored pk")?;

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(
                Bytes::from(
                    IAMMAuctionSuapp::setSigningKeyCall {
                        keyNonce: U256::from(nonce),
                    }
                    .abi_encode(),
                )
                .into(),
            );

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node);
        self.send_ccr(ConfidentialComputeRequest::new(
            cc_record,
            suave_stored_wallet_pk.into(),
        ))
        .await
        .wrap_err("failed to send init signing key CCR")?;
        Ok(())
    }
}

// #[cfg(test)]
// mod tests {
// use std::str::FromStr;
//
// use super::*;
//
// #[tokio::test]
// async fn test_send_tx() {
// let suave_rpc = "http://127.0.0.1:8545";
// let contract_address =
// Address::from_str("0xd594760B2A36467ec7F0267382564772D7b0b73c").unwrap();
// let execution_node =
// Address::from_str("0xb5feafbdd752ad52afb7e1bd2e40432a485bbb7f").unwrap();
// let signer_pk = "0x6c45335a22461ccdb978b78ab61b238bad2fae4544fb55c14eb096c875ccfc52";
//
// let signer_wallet: LocalWallet = signer_pk.parse().unwrap();
// let pk = signer_wallet.
// let signers = vec![signer_pk.to_string()];
// let amm_auction_contract = AmmAuctionSuapp::new(
// contract_address,
// execution_node,
// suave_rpc.to_string(),
// &signers,
// )
// .await
// .expect("failed to build amm auction contract");
//
// let test_ccr = amm_auction_contract
// .new_pending_txn(signer_wallet.address(), Bytes::new())
// .await
// .expect("failed to build ccr");
//
// amm_auction_contract
// .send_ccr(signer_wallet.address(), test_ccr)
// .await
// .expect("failed sending ccr");
// }
// }
