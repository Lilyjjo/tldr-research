use std::collections::HashMap;

use alloy_primitives::{
    Address,
    Bytes,
    FixedBytes,
    B256,
    U16,
    U160,
    U256,
};
use color_eyre::eyre::{
    self,
    Context,
    Error,
};
use futures_util::{
    stream::StreamExt,
    SinkExt,
};
use serde_json::Value;
use suave_rust::amm_auction_suapp::{
    self,
    AmmAuctionSuapp,
};
use tokio::{
    process::Command,
    task::JoinHandle,
    time::{
        sleep,
        Duration,
    },
};
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
    pub async fn new(l1_websocket: String) -> eyre::Result<Self> {
        // Setup the WebSocket server URL
        let url = Url::parse(&l1_websocket).context("failed to parse URL")?;

        Ok(Self {
            l1_websocket_url: url,
        })
    }

    pub async fn run_until_stopped(
        &mut self,
        amm_auction_suapp: AmmAuctionSuapp,
    ) -> eyre::Result<JoinHandle<()>> {
        // Connect to the server
        let (ws_stream, _) = connect_async(self.l1_websocket_url.clone())
            .await
            .wrap_err("failed to connect to L1 websocket")?;

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
            .wrap_err("failed to send subscription method to websocket")?;

        // Spawn a task to handle incoming messages
        let api_task = tokio::spawn(async move {
            let mut amm_auction_suapp = amm_auction_suapp;
            while let Some(message) = read.next().await {
                match message {
                    Ok(msg) => match msg {
                        Message::Text(text) => process_header(&mut amm_auction_suapp, text).await,
                        _ => (),
                    },
                    Err(e) => println!("error receiving message: {:?}", e),
                }
            }
        });

        Ok(api_task)
    }
}

async fn trigger_auction(amm_auction_suapp: &mut AmmAuctionSuapp) {
    // sleep a few seconds to let auction time pass
    sleep(Duration::from_secs(2)).await;

    if let Err(e) = amm_auction_suapp.trigger_auction().await {
        print!("{}", e);
    }
    sleep(Duration::from_secs(3)).await;
    if let Err(e) = amm_auction_suapp.print_auction_stats().await {
        print!("{}", e);
    }
}

async fn process_header(amm_auction_suapp: &mut AmmAuctionSuapp, text: String) {
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

    if timestamp != 0 {
        // don't run on first message
        trigger_auction(amm_auction_suapp).await;
    }
}
