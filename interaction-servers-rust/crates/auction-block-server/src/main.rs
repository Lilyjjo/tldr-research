use auction_block_server::BlockServer;

#[tokio::main]
async fn main() {
    // load environment variables
    let env_file = if cfg!(feature = "local") {
        "local.env"
    } else {
        "rigil.env"
    };
    println!("{}", env_file);
    dotenv::from_filename(env_file).ok();

    let rpc_url: String = std::env::var("WSS_SEPOLIA").expect("WSS_SEPOLIA env var not set");

    // setup block server
    let block_server = BlockServer::new(rpc_url)
        .await
        .expect("failed to create new block server")
        .run_until_stopped()
        .await
        .expect("failed to start block server");

    block_server.await.unwrap();
}
