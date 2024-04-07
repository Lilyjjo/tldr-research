use block_server::BlockServer;
use dotenv::dotenv;

#[tokio::main]
async fn main() {
    // load env vars
    dotenv().ok();
    let rpc_url: String = std::env::var("L1_RPC_URL").expect("L1_RPC_URL env var not set");

    // setup block server
    let block_server = BlockServer::new(rpc_url)
        .await
        .expect("failed to create new block server")
        .run_until_stopped()
        .await
        .expect("failed to start block server");

    block_server.await.unwrap();
}
