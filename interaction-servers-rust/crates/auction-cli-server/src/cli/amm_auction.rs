use std::str::FromStr;

use clap::{
    Args,
    Subcommand,
};
use color_eyre::eyre;
use serde::Serialize;

#[derive(Debug, Subcommand)]
pub enum Command {
    Auction(AuctionArgs),
    Bid(BidArgs),
    SwapTx(SwapArgs),
    InitializeSuapp(InitializeSuappArgs),
}

#[derive(Args, Debug)]
pub struct AuctionArgs {
    #[clap(long, default_value = "0")]
    pub(crate) target_block: u128,
}

#[derive(Args, Debug)]
pub struct BidArgs {
    #[clap(long, default_value = "10")]
    pub(crate) target_block: u128,
    #[clap(long)]
    pub(crate) bidder: String,
    #[clap(long, default_value = "10")]
    pub(crate) bid_amount: u128,
    #[clap(long, default_value = "10")]
    pub(crate) swap_amount: u128,
    #[clap(long, default_value = "true")]
    pub(crate) token_0_in: bool,
}

#[derive(Args, Debug)]
pub struct SwapArgs {
    #[clap(long)]
    pub(crate) swapper: String,
    #[clap(long, default_value = "10")]
    pub(crate) swap_amount: u128,
    #[clap(long, default_value = "true")]
    pub(crate) token_0_in: bool,
}

#[derive(Args, Debug)]
pub struct InitializeSuappArgs {}
