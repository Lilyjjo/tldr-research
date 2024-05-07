use auction_interface::amm_auction::AuctionSuapp;
use color_eyre::eyre::{self, Context};
use futures_util::{stream::StreamExt, SinkExt};
use serde_json::Value;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::{
    task::JoinHandle,
    time::{sleep, Duration},
};
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
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
        amm_auction_suapp: AuctionSuapp,
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
                    Err(e) => println!("error receiving message: {}", e),
                }
            }
        });

        Ok(api_task)
    }
}

fn get_random_amount() -> u128 {
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_micros();

    (seed % 100) + 1
}

async fn trigger_auction(amm_auction_suapp: &mut AuctionSuapp, block_number: u128) {
    println!("[~~~~  running auction for block: {} ~~~~]", block_number);

    let mut bid_amount = get_random_amount();
    // send bids
    if let Err(e) = amm_auction_suapp
        .new_bid(&"bidder_0".to_string(), block_number, bid_amount, 10, true)
        .await
    {
        println!("--> !!! failed to send bid for bidder_0: {}", e);
    } else {
        println!("--> sent bid for bidder_0 for: {}", bid_amount);
    }
    bid_amount = get_random_amount();
    if let Err(e) = amm_auction_suapp
        .new_bid(&"bidder_1".to_string(), block_number, bid_amount, 10, true)
        .await
    {
        println!("--> !!! failed to send bid for bidder_1: {}", e);
    } else {
        println!("--> sent bid for bidder_1 for: {}", bid_amount);
    }
    bid_amount = get_random_amount();
    if let Err(e) = amm_auction_suapp
        .new_bid(&"bidder_2".to_string(), block_number, bid_amount, 10, true)
        .await
    {
        println!("--> !!! failed to send bid for bidder_2: {}", e);
    } else {
        println!("--> sent bid for bidder_2 for: {}", bid_amount);
    }

    // sleep a few seconds to let auction time pass
    sleep(Duration::from_secs(4)).await;

    if let Err(e) = amm_auction_suapp.trigger_auction().await {
        println!("--> !!! failed to trigger auction: {}", e);
    } else {
        println!("--| triggered auction");
    }

    sleep(Duration::from_secs(5)).await;
    if let Err(e) = amm_auction_suapp.print_auction_stats().await {
        println!("!! {} !!", e);
    }
}

async fn process_header(amm_auction_suapp: &mut AuctionSuapp, text: String) {
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

    if timestamp != 0 {
        // don't run on first message
        trigger_auction(amm_auction_suapp, block_number + 1).await;
    }
}
