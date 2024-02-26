use dotenv::dotenv;
use futures_util::sink::SinkExt;
use futures_util::stream::StreamExt;
use serde_json::Value;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use url::Url;

async fn process_header(text: String) {
    let v: Value = serde_json::from_str(&text).unwrap();

    let mut block_number: u128 = 0;
    if let Value::String(result) = &v["params"]["result"]["number"] {
        block_number =
            u128::from_str_radix(&result[2..], 16).expect("hex parsing failed for block number");
    }

    let mut timestamp: u128 = 0;
    if let Value::String(result) = &v["params"]["result"]["timestamp"] {
        timestamp =
            u128::from_str_radix(&result[2..], 16).expect("hex parsing failed for timestamp");
    }

    println!("timestamp: {}", timestamp);
    println!("block_number: {}", block_number);

    // todo: use to trigger auction logic
}

#[tokio::main]
async fn main() {
    // load env vars
    dotenv().ok();
    let rpc_url: String = std::env::var("L1_RPC_URL").expect("L1_RPC_URL env var not set");

    // Setup the WebSocket server URL
    let url = Url::parse(&rpc_url).expect("Failed to parse URL");

    // Connect to the server
    let (ws_stream, _) = connect_async(url).await.expect("Failed to connect");

    println!("WebSocket handshake has been successfully completed");

    // Split the stream into a sender and receiver
    let (mut write, mut read) = ws_stream.split();

    // Send a message to start subscription
    let msg = Message::Text("{\"jsonrpc\":\"2.0\",\"id\": 2, \"method\": \"eth_subscribe\", \"params\": [\"newHeads\"]}".into());
    write.send(msg).await.expect("Failed to send message");

    // Spawn a task to handle incoming messages
    tokio::spawn(async move {
        while let Some(message) = read.next().await {
            match message {
                Ok(msg) => {
                    match msg {
                        Message::Text(text) => process_header(text).await,
                        // Handle other message types as needed
                        _ => (),
                    }
                }
                Err(e) => println!("Error receiving message: {:?}", e),
            }
        }
    });

    // Keep the task alive (or perform other tasks)
    // Here we simply sleep, but in a real app, you might be running a server or other tasks.
    tokio::time::sleep(tokio::time::Duration::from_secs(3600)).await; // stay awake for an hour
}
