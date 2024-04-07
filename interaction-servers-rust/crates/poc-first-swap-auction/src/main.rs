use block_server::BlockServer;

#[tokio::main]
async fn main() {
    let block_server = BlockServer::new()
        .await
        .expect("failed to create new block server");
    let block_server_join_handle = block_server
        .run_until_stopped()
        .await
        .expect("failed to start block server");

    block_server_join_handle.await.unwrap();
}
