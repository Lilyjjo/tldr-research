use alloy_primitives::Address;
use eyre::Context;
use serde::Deserialize;

#[derive(Deserialize, Clone)]
pub struct AmmAuctionConfig {
    pub use_local: bool,
    pub execution_node_suave_local: Address,
    pub execution_node_suave: Address,
    pub suave_signer_local: Address,
    pub suave_signer_local_pk: String,
    pub suave_signer: Address,
    pub suave_signer_pk: String,
    pub suapp_signer: Address,
    pub suapp_signer_pk: String,
    pub bidder_0: Address,
    pub bidder_0_pk: String,
    pub bidder_1: Address,
    pub bidder_1_pk: String,
    pub bidder_2: Address,
    pub bidder_2_pk: String,
    pub swapper_0: Address,
    pub swapper_0_pk: String,
    pub swapper_1: Address,
    pub swapper_1_pk: String,
    pub swapper_2: Address,
    pub swapper_2_pk: String,
    pub chain_id_l1: u64,
    pub chain_id_suave: u64,
    pub rpc_url_l1: String,
    pub wss_l1: String,
    pub rpc_url_suave_local: String,
    pub rpc_url_suave: String,
    pub rpc_url_bundle: String,
    pub rpc_url_suave_execution_endpoint: Option<String>,
    pub suapp_amm: Option<Address>,
    pub auction_deposits: Option<Address>,
    pub auction_guard: Option<Address>,
    pub swap_router: Option<Address>,
    pub token_0: Option<Address>,
    pub token_1: Option<Address>,
}

impl AmmAuctionConfig {
    pub async fn new(env_file: &str) -> eyre::Result<AmmAuctionConfig> {
        println!("env file in use: {}", env_file);
        dotenv::from_filename(env_file).ok();

        let config: AmmAuctionConfig = envy::from_env().wrap_err("Error parsing .env")?;
        Ok(config)
    }
}
