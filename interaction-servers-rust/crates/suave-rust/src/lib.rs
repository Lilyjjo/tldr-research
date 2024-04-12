pub mod ccr;
use std::collections::HashMap;

use alloy::{
    network::TransactionBuilder,
    providers::{layers::SignerProvider, Provider, ProviderBuilder, RootProvider},
    rpc::types::eth::TransactionRequest,
    signers::wallet::LocalWallet,
    transports::http::Http,
};
use alloy_primitives::{Address, Bytes, B256, U256};
use alloy_sol_types::{sol, SolCall};
use anyhow::{bail, Context};
use reqwest;

use crate::ccr::{
    ConfidentialComputeRecord, ConfidentialComputeRequest, SuaveNetwork, SuaveSigner,
};

sol! {
    #[derive(Debug, PartialEq)]
    interface AMMAuctionSuapp {
        function newPendingTxn() external returns (bytes memory);
    }
}

pub struct AmmAuctionSuapp {
    contract_address: Address,
    execution_node: Address,
    provider: RootProvider<Http<reqwest::Client>>,
    signer_providers: HashMap<
        Address,
        SignerProvider<
            Http<reqwest::Client>,
            RootProvider<Http<reqwest::Client>, SuaveNetwork>,
            SuaveSigner,
            SuaveNetwork,
        >,
    >,
}

// send(to contract (on network), from entity)
// contracts (with networks), sent to functions from entities
impl AmmAuctionSuapp {
    pub async fn new(
        contract_address: Address,
        execution_node: Address,
        suave_rpc: String,
        initial_signers_pks: &Vec<String>,
    ) -> anyhow::Result<Self> {
        // TODO: this is not built in a clean manner, redo one day if time
        // build normal provider
        let rpc_url =
            url::Url::parse(&suave_rpc).context("failed to build url from suave rpc string")?;
        let provider = ProviderBuilder::new()
            .on_reqwest_http(rpc_url.clone())
            .context("failed to build provider from given rpc url")?;
        // build CCR signers
        let mut signer_providers = HashMap::new();
        for signer_pk in initial_signers_pks {
            let wallet: LocalWallet = signer_pk
                .parse()
                .context("failed to parse pk from input string")?;
            let pub_key_cache = wallet.address();
            let signer_provider = ProviderBuilder::<_, SuaveNetwork>::default()
                .signer(SuaveSigner::from(wallet))
                .on_reqwest_http(rpc_url.clone())
                .context("failed to build signer wallet")?;
            signer_providers.insert(pub_key_cache, signer_provider);
        }
        Ok(AmmAuctionSuapp {
            contract_address,
            execution_node,
            provider,
            signer_providers,
        })
    }

    pub async fn send_ccr(
        &self,
        signer: Address,
        confidential_compute_request: ConfidentialComputeRequest,
    ) -> anyhow::Result<()> {
        // TODO add better error handling, maybe even skipping getting response?
        if let Some(provider) = self.signer_providers.get(&signer) {
            println!("sending ccr");
            let result = provider
                .send_transaction(confidential_compute_request)
                .await
                .context("failed to send ccr")?;
            let tx_hash = B256::from_slice(&result.tx_hash().to_vec());
            println!("retrieving response");
            let tx_response = provider.get_transaction_by_hash(tx_hash).await.unwrap();
            println!("{:#?}", tx_response);
            Ok(())
        } else {
            bail!("provider for address not created")
        }
    }

    pub async fn build_generic_transaction(
        &self,
        signer: Address,
    ) -> anyhow::Result<TransactionRequest> {
        // gather network dependent variables
        let nonce = self
            .provider
            .get_transaction_count(signer, None)
            .await
            .context("failed to get transaction count for address")?;

        let gas_price = self
            .provider
            .get_gas_price()
            .await
            .context("failed to get gas price")?;

        let gas = 0x0f4240; // TODO: figure out what is reasonable, probably should be per function

        let chain_id = self
            .provider
            .get_chain_id()
            .await
            .context("failed to get chain id")?;

        let tx = TransactionRequest::default()
            .to(Some(self.contract_address))
            .gas_limit(U256::from(gas))
            .with_gas_price(gas_price)
            .with_chain_id(chain_id.to::<u64>())
            .with_nonce(nonce.to::<u64>());
        Ok(tx)
    }

    pub async fn new_pending_txn(
        &self,
        signer: Address,
        signed_txn: Bytes,
    ) -> anyhow::Result<ConfidentialComputeRequest> {
        // create generic transaction request and add function specific data
        let tx = self
            .build_generic_transaction(signer)
            .await
            .context("failed to build generic transaction")?
            .input(Bytes::from(AMMAuctionSuapp::newPendingTxnCall::SELECTOR).into());

        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, self.execution_node);
        Ok(ConfidentialComputeRequest::new(cc_record, signed_txn))
    }
}

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use super::*;

    #[tokio::test]
    async fn test_send_tx() {
        let suave_rpc = "http://127.0.0.1:8545";
        let contract_address =
            Address::from_str("0xd594760B2A36467ec7F0267382564772D7b0b73c").unwrap();
        let execution_node =
            Address::from_str("0xb5feafbdd752ad52afb7e1bd2e40432a485bbb7f").unwrap();
        let signer_pk = "0x6c45335a22461ccdb978b78ab61b238bad2fae4544fb55c14eb096c875ccfc52";

        let signer_wallet: LocalWallet = signer_pk.parse().unwrap();
        // let pk = signer_wallet.
        let signers = vec![signer_pk.to_string()];
        let amm_auction_contract = AmmAuctionSuapp::new(
            contract_address,
            execution_node,
            suave_rpc.to_string(),
            &signers,
        )
        .await
        .expect("failed to build amm auction contract");

        let test_ccr = amm_auction_contract
            .new_pending_txn(signer_wallet.address(), Bytes::new())
            .await
            .expect("failed to build ccr");

        amm_auction_contract
            .send_ccr(signer_wallet.address(), test_ccr)
            .await
            .expect("failed sending ccr");
    }
}
