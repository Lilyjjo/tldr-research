use std::collections::HashMap;

use alloy::{
    eips::{eip2718::Encodable2718, BlockId},
    network::{EthereumSigner, TransactionBuilder},
    providers::{fillers::FillProvider, Provider, ProviderBuilder, RootProvider, WalletProvider},
    rpc::types::eth::{TransactionInput, TransactionRequest},
    signers::{wallet::LocalWallet, Signer},
    sol,
    transports::http::Http,
};
use alloy_primitives::{Address, Bytes, B256, U256};
use alloy_sol_types::{SolCall, SolStruct, SolValue};
use color_eyre::{eyre, eyre::Context};
use eyre::ContextCompat;
use reqwest::Client as ReqwestClient;
use suave_alloy::{
    self,
    network::{KettleFiller, SuaveNetwork, SuaveProvider, SuaveSigner},
    types::{ConfidentialComputeRecord, ConfidentialComputeRequest},
};

use crate::amm_auction_config::AmmAuctionConfig;

sol! {
    #[sol(rpc)]
    interface IAuctionSuapp {
        #[derive(Debug)]
        function newPendingTxn() external returns (bytes memory);
        #[derive(Debug)]
        function newBid(string memory salt) external returns (bytes memory);
        #[derive(Debug)]
        function runAuction() external returns (bytes memory);
        #[derive(Debug)]
        function setSigningKey(address pubKey) external returns (bytes memory);
        #[derive(Debug)]
        function setL1Url() external returns (bytes memory);
        #[derive(Debug)]
        function setBundleUrl() external returns (bytes memory);
        #[derive(Debug)]
        function initLastL1Block() external returns (bytes memory);
        #[derive(Debug)]
        function _resetSwaps() external returns (bytes memory);

        struct Bid {
            address bidder;
            uint256 blockNumber;
            uint256 amount;
            bytes swapTxn;
            uint8 v;
            bytes32 r;
            bytes32 s;
        }
    }

    struct WithdrawBid{
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

pub struct AuctionSuapp {
    auction_suapp: Address,
    deposit_contract: Address,
    token_0: Address,
    token_1: Address,
    swap_router: Address,
    execution_node: Address,
    l1_provider: RootProvider<Http<ReqwestClient>>,
    suave_provider: FillProvider<
        alloy::providers::fillers::JoinFill<
            alloy::providers::fillers::JoinFill<
                alloy::providers::fillers::JoinFill<
                    alloy::providers::fillers::JoinFill<
                        alloy::providers::fillers::JoinFill<
                            alloy::providers::Identity,
                            alloy::providers::fillers::GasFiller,
                        >,
                        alloy::providers::fillers::NonceFiller,
                    >,
                    alloy::providers::fillers::ChainIdFiller,
                >,
                KettleFiller,
            >,
            alloy::providers::fillers::SignerFiller<SuaveSigner>,
        >,
        SuaveProvider<Http<ReqwestClient>>,
        Http<ReqwestClient>,
        SuaveNetwork,
    >,
    eoa_wallets: HashMap<String, LocalWallet>,
    l1_rpc: String,
    bundle_rpc: String,
    last_used_suave_nonce: u64,
}

impl AuctionSuapp {
    pub async fn new_from_config(config: AmmAuctionConfig) -> eyre::Result<Self> {
        let execution_node;
        let suave_rpc;
        let suave_signer_pk;
        if config.use_local {
            execution_node = config.execution_node_suave_local;
            suave_rpc = config.rpc_url_suave_local;
            suave_signer_pk = config.suave_signer_local_pk;
        } else {
            execution_node = config.execution_node_suave;
            suave_rpc = config.rpc_url_suave;
            suave_signer_pk = config.suave_signer_pk;
        }

        // construct eoa accounts
        let mut eoas = HashMap::<String, LocalWallet>::new();
        eoas.insert(
            "suave_signer".to_string(),
            suave_signer_pk
                .parse()
                .context("failed to parse suave_signer's pk")?,
        );
        eoas.insert(
            "suapp_signer".to_string(),
            config
                .suapp_signer_pk
                .parse()
                .context("failed to parse suapp_signer's pk")?,
        );
        eoas.insert(
            "bidder_0".to_string(),
            config
                .bidder_0_pk
                .parse()
                .context("failed to parse bidder_0's pk")?,
        );
        eoas.insert(
            "bidder_1".to_string(),
            config
                .bidder_1_pk
                .parse()
                .context("failed to parse bidder_1's pk")?,
        );
        eoas.insert(
            "bidder_2".to_string(),
            config
                .bidder_2_pk
                .parse()
                .context("failed to parse bidder_2's pk")?,
        );
        eoas.insert(
            "swapper_0".to_string(),
            config
                .swapper_0_pk
                .parse()
                .context("failed to parse swapper_0's pk")?,
        );
        eoas.insert(
            "swapper_1".to_string(),
            config
                .swapper_1_pk
                .parse()
                .context("failed to parse swapper_1's pk")?,
        );
        eoas.insert(
            "swapper_2".to_string(),
            config
                .swapper_2_pk
                .parse()
                .context("failed to parse swapper_2's pk")?,
        );

        AuctionSuapp::new(
            config.suapp_amm.context("auction suapp not set")?,
            config
                .auction_deposits
                .context("auction deposits not set")?,
            config.token_0.context("auction deposits not set")?,
            config.token_1.context("auction deposits not set")?,
            config.swap_router.context("swap router not set")?,
            execution_node,
            suave_rpc,
            config.rpc_url_l1,
            config.rpc_url_bundle,
            eoas,
        )
        .await
    }

    pub async fn new(
        auction_suapp: Address,
        deposit_contract: Address,
        token_0: Address,
        token_1: Address,
        swap_router: Address,
        execution_node: Address,
        suave_rpc: String,
        l1_rpc: String,
        bundle_rpc: String,
        eoa_accounts: HashMap<String, LocalWallet>,
    ) -> eyre::Result<Self> {
        // build L1 provider
        let l1_rpc_url =
            url::Url::parse(&l1_rpc).context("failed to build url from suave rpc string")?;
        let l1_provider = ProviderBuilder::new()
            .on_http(l1_rpc_url.clone())
            .context("failed to build provider from given rpc url")?;

        // build suave provider
        let suave_signer_wallet = eoa_accounts.get("suave_signer").unwrap().clone();
        let suave_rpc_url =
            url::Url::parse(&suave_rpc).context("failed to build url from suave rpc string")?;
        let suave_provider = ProviderBuilder::<_, _, SuaveNetwork>::default()
            .with_recommended_fillers()
            .filler(KettleFiller::default())
            .signer(SuaveSigner::new(suave_signer_wallet))
            .on_provider(SuaveProvider::from_http(suave_rpc_url));

        Ok(AuctionSuapp {
            auction_suapp,
            deposit_contract,
            token_0,
            token_1,
            swap_router,
            execution_node,
            l1_provider,
            suave_provider,
            eoa_wallets: eoa_accounts,
            l1_rpc,
            bundle_rpc,
            last_used_suave_nonce: 0,
        })
    }

    pub async fn send_ccr(
        &self,
        confidential_compute_request: ConfidentialComputeRequest,
    ) -> eyre::Result<()> {
        // TODO add better error handling, maybe even skipping getting response?
        let result = self
            .suave_provider
            .send_transaction(confidential_compute_request)
            .await
            .context("failed to send ccr")?;
        let tx_hash = B256::from_slice(&result.tx_hash().to_vec());
        let _ = self
            .suave_provider
            .get_transaction_by_hash(tx_hash)
            .await
            .context("failed to get transaction hash receipt");
        Ok(())
    }

    pub async fn build_generic_suave_transaction(
        &mut self,
        signer: Address,
    ) -> eyre::Result<TransactionRequest> {
        // gather network dependent variables
        let mut nonce = self
            .suave_provider
            .get_transaction_count(signer, BlockId::default())
            .await
            .context("failed to get transaction count for address")?;

        // nonce management for sending CCRs without waiting for others to complete
        if self.last_used_suave_nonce >= nonce {
            nonce = self.last_used_suave_nonce + 1;
        }
        self.last_used_suave_nonce = nonce;

        let gas_price = self
            .suave_provider
            .get_gas_price()
            .await
            .context("failed to get gas price")?
            .wrapping_add(1_000_000);

        let gas = 0x2f4240; // TODO: figure out what is reasonable, probably should be per function

        let chain_id = self
            .suave_provider
            .get_chain_id()
            .await
            .context("failed to get chain id")?;

        let tx = TransactionRequest::default()
            .to(self.auction_suapp)
            .gas_limit(gas)
            .with_gas_price(gas_price)
            .with_chain_id(chain_id)
            .with_nonce(nonce);
        Ok(tx)
    }

    pub async fn build_generic_l1_transaction(
        &self,
        signer: Address,
        target_contract: Address,
    ) -> eyre::Result<TransactionRequest> {
        // gather network dependent variables
        let nonce = self
            .l1_provider
            .get_transaction_count(signer, BlockId::default())
            .await
            .context("failed to get transaction count for address")?;

        let gas_price = self
            .l1_provider
            .get_gas_price()
            .await
            .context("failed to get gas price")?
            .wrapping_add(1_000_000_000); // to account for gas fluction between creation and sending

        let gas = 0x0f4240; // TODO: figure out what is reasonable, probably should be per function

        let chain_id = self
            .l1_provider
            .get_chain_id()
            .await
            .context("failed to get chain id")?;

        let tx = TransactionRequest::default()
            .to(target_contract)
            .gas_limit(gas)
            .with_gas_price(gas_price)
            .with_chain_id(chain_id)
            .with_nonce(nonce);
        Ok(tx)
    }

    pub async fn new_pending_swap_txn(
        &self,
        swapper: LocalWallet,
        in_amount: u128,
        token_0_in: bool,
    ) -> eyre::Result<Vec<u8>> {
        // create swap router transaction input
        let (token_in, token_out) = if token_0_in {
            (self.token_0, self.token_1)
        } else {
            (self.token_1, self.token_0)
        };

        let swap_input_params = ISwapRouter::ExactInputSingleParams {
            tokenIn: token_in,
            tokenOut: token_out,
            fee: 3000u32,
            recipient: swapper.address(),
            deadline: U256::from(1776038248), // 4/12/2026
            amountIn: U256::from(in_amount),
            amountOutMinimum: U256::from(1),
            sqrtPriceLimitX96: U256::from(0),
        };

        // create and sign over the swap transaction
        let mut rlp_encoded_swap_tx = Vec::new();
        self.build_generic_l1_transaction(swapper.address(), self.swap_router)
            .await
            .context("failed to build generic L1 transaction")?
            .input(TransactionInput::new(
                ISwapRouter::exactInputSingleCall {
                    params: swap_input_params,
                }
                .abi_encode()
                .into(),
            ))
            .build(&EthereumSigner::from(swapper))
            .await
            .context("failed to sign transaction")?
            .encode_2718(&mut rlp_encoded_swap_tx);

        Ok(rlp_encoded_swap_tx)
    }

    pub async fn trigger_auction(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAuctionSuapp::runAuctionCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(cc_record, None))
            .await
            .context("failed to send trigger auction CCR")?;
        Ok(())
    }

    pub async fn new_pending_txn(
        &mut self,
        swapper: &String,
        amount_in: u128,
        token_0_in: bool,
    ) -> eyre::Result<()> {
        let swapper = self
            .eoa_wallets
            .get(swapper)
            .expect("swapper's wallet not initialized");

        let signed_swap_transaction = self
            .new_pending_swap_txn(swapper.clone(), amount_in, token_0_in)
            .await
            .context("failed to create swap transaction for new pending tx")?;

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(self.suave_provider.default_signer_address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAuctionSuapp::newPendingTxnCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(
            cc_record,
            Some(signed_swap_transaction.into()),
        ))
        .await
        .context("failed to send swap CCR")?;
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
            .eoa_wallets
            .get(bidder)
            .expect("bidders's wallet not initialized");
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        // create swap router transaction input
        let signed_swap_txn = self
            .new_pending_swap_txn(bidder.clone(), in_amount, token_0_in)
            .await
            .context("failed when building bid's inner swap transaction")?;

        // create and sign over withdraw 712 request
        let my_domain: alloy_sol_types::Eip712Domain = alloy_sol_types::eip712_domain!(
            name: "AuctionDeposits",
            version: "v1",
            chain_id: 17000u64, // holesky
            verifying_contract: self.deposit_contract,
        );

        let bid_request = WithdrawBid {
            bidder: bidder.address(),
            blockNumber: U256::from(block_number),
            amount: U256::from(bid_amount),
        };

        let bid_signing_hash = bid_request.eip712_signing_hash(&my_domain);
        let bid_signature = bidder
            .sign_hash(&bid_signing_hash)
            .await
            .context("failed to sign bid EIP712 hash")?;

        // create bid input
        let bid = IAuctionSuapp::Bid {
            bidder: bidder.address(),
            blockNumber: U256::from(block_number),
            amount: U256::from(bid_amount),
            swapTxn: signed_swap_txn.into(),
            v: bid_signature.v().y_parity_byte() + 27,
            r: bid_signature.r().into(),
            s: bid_signature.s().into(),
        }
        .abi_encode();

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic suave transaction")?
            .input(
                Bytes::from(
                    IAuctionSuapp::newBidCall {
                        salt: "111".to_string(),
                    }
                    .abi_encode(),
                )
                .into(),
            );

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;

        self.send_ccr(ConfidentialComputeRequest::new(cc_record, Some(bid.into())))
            .await
            .context("failed to send bid CCR")?;
        Ok(())
    }

    pub async fn clear_swaps(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAuctionSuapp::_resetSwapsCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(cc_record, None))
            .await
            .context("failed to send clear swaps CCR")?;
        Ok(())
    }

    pub async fn initialize_l1_block(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAuctionSuapp::initLastL1BlockCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(cc_record, None))
            .await
            .context("failed to send L1 block init CCR")?;
        Ok(())
    }

    pub async fn set_l1_url(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        let confidential_inputs = self.l1_rpc.abi_encode_packed();

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAuctionSuapp::setL1UrlCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(
            cc_record,
            Some(confidential_inputs.into()),
        ))
        .await
        .context("failed to send L1 init CCR")?;
        Ok(())
    }

    pub async fn set_bundle_url(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        let confidential_inputs = self.bundle_rpc.abi_encode_packed();

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(IAuctionSuapp::setBundleUrlCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(
            cc_record,
            Some(confidential_inputs.into()),
        ))
        .await
        .context("failed to send bundle init CCR")?;
        Ok(())
    }

    pub async fn set_signing_key(&mut self) -> eyre::Result<()> {
        let suave_signer = self
            .eoa_wallets
            .get("suave_signer")
            .expect("funded suave's wallet not initialized");

        let suave_stored_wallet_pk = self
            .eoa_wallets
            .get("suapp_signer")
            .expect("suapp's signing wallet not initialized")
            .signer()
            .to_bytes()
            .abi_encode_packed();

        let suave_stored_wallet_address = self
            .eoa_wallets
            .get("suapp_signer")
            .expect("suapp's signing wallet not initialized")
            .address();

        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_suave_transaction(suave_signer.address())
            .await
            .context("failed to build generic transaction")?
            .input(
                Bytes::from(
                    IAuctionSuapp::setSigningKeyCall {
                        pubKey: suave_stored_wallet_address,
                    }
                    .abi_encode(),
                )
                .into(),
            );

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node)
            .context("failed to create ccr")?;
        self.send_ccr(ConfidentialComputeRequest::new(
            cc_record,
            Some(suave_stored_wallet_pk.into()),
        ))
        .await
        .context("failed to send init signing key CCR")?;
        Ok(())
    }

    pub async fn print_auction_stats(&mut self) -> eyre::Result<()> {
        // grab from amm's visibility storage slots
        let slot_0 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(0), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_1 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(1), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_2 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(2), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_3 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(3), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_4 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(4), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_5 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(5), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_6 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(6), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;
        let slot_7 = self
            .suave_provider
            .get_storage_at(self.auction_suapp, U256::from(7), BlockId::latest())
            .await
            .context("failed grabbing amm's storage slot")?;

        println!("Auction Stats");
        println!("  auctioned block      : {}", slot_0);
        println!("  last nonce used      : {}", slot_1);
        println!("  included swap txns   : {}", slot_2);
        println!("  total landed         : {}", slot_4);
        println!("  winning bid $        : {}", slot_5);

        Ok(())
    }
}
