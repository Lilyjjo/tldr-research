use dotenv::dotenv;
use futures_util::{stream::StreamExt, SinkExt};
use serde_json::Value;
use tokio::task::JoinHandle;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use url::Url;

/// `BlockServer` is a service responsible for listening for new block produced on the given RCP websocket endpoint and performing an action.
pub struct BlockServer {
    // L1 websocket url
    l1_websocket_url: Url,
}

impl BlockServer {
    pub async fn new() -> anyhow::Result<Self> {
        // load env vars
        dotenv().ok();
        let rpc_url: String = std::env::var("L1_RPC_URL").expect("L1_RPC_URL env var not set");

        // Setup the WebSocket server URL
        let url = Url::parse(&rpc_url).expect("Failed to parse URL");

        Ok(Self {
            l1_websocket_url: url,
        })
    }

    pub async fn run_until_stopped(self) -> anyhow::Result<JoinHandle<()>> {
        // Connect to the server
        let (ws_stream, _) = connect_async(self.l1_websocket_url)
            .await
            .expect("Failed to connect");

        // Split the stream into a sender and receiver
        let (mut write, mut read) = ws_stream.split();

        // Send a message to start subscription
        let msg = Message::Text("{\"jsonrpc\":\"2.0\",\"id\": 2, \"method\": \"eth_subscribe\", \"params\": [\"newHeads\"]}".into());
        write.send(msg).await.expect("Failed to send message");

        // Spawn a task to handle incoming messages
        let api_task = tokio::spawn(async move {
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

        Ok(api_task)
    }
}

async fn trigger_auction() {
    // TODO: redo using Alloy
    /*
    let mut child = Command::new("forge")
        .current_dir("../../../poc_first_swap_auction/")
        .arg("script")
        .arg("script/Interactions.s.sol:Interactions")
        .arg("--sig")
        .arg("testCall()")
        .spawn()
        .expect("Failed to start child process");

    let _result = child.wait().unwrap();
    */
}

async fn process_header(text: String) {
    println!("In process_header");
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

    trigger_auction().await;
}
