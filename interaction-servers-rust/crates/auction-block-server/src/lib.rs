use anyhow::Context;
use futures_util::{
    stream::StreamExt,
    SinkExt,
};
use serde_json::Value;
use tokio::task::JoinHandle;
use tokio_tungstenite::{
    connect_async,
    tungstenite::protocol::Message,
};
use url::Url;

/// `BlockServer` is a service responsible for listening for new block produced on the given RCP
/// websocket endpoint and performing an action.
pub struct BlockServer {
    // L1 websocket url
    l1_websocket_url: Url,
}

impl BlockServer {
    pub async fn new(l1_websocket: String) -> anyhow::Result<Self> {
        // Setup the WebSocket server URL
        let url = Url::parse(&l1_websocket).context("failed to parse URL")?;

        Ok(Self {
            l1_websocket_url: url,
        })
    }

    pub async fn run_until_stopped(self) -> anyhow::Result<JoinHandle<()>> {
        // Connect to the server
        let (ws_stream, _) = connect_async(self.l1_websocket_url)
            .await
            .context("failed to connect to L1 websocket")?;

        // Split the stream into a sender and receiver
        let (mut write, mut read) = ws_stream.split();

        // Send a message to start subscription
        let msg = Message::Text(
            "{\"jsonrpc\":\"2.0\",\"id\": 2, \"method\": \"eth_subscribe\", \"params\": \
             [\"newHeads\"]}"
                .into(),
        );
        write
            .send(msg)
            .await
            .context("failed to send subscription method to websocket")?;

        // Spawn a task to handle incoming messages
        let api_task = tokio::spawn(async move {
            while let Some(message) = read.next().await {
                match message {
                    Ok(msg) => match msg {
                        Message::Text(text) => process_header(text).await,
                        _ => (),
                    },
                    Err(e) => println!("error receiving message: {:?}", e),
                }
            }
        });

        Ok(api_task)
    }
}

async fn trigger_auction() {
    // TODO: redo using Alloy
    // let mut child = Command::new("forge")
    // .current_dir("../../../poc_first_swap_auction/")
    // .arg("script")
    // .arg("script/Interactions.s.sol:Interactions")
    // .arg("--sig")
    // .arg("testCall()")
    // .spawn()
    // .expect("Failed to start child process");
    //
    // let _result = child.wait().unwrap();
}

async fn process_header(text: String) {
    // TODO add better error handling around this
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
