pub(crate) mod amm_auction;
use clap::{
    Parser,
    Subcommand,
};
use color_eyre::eyre;

use crate::cli::amm_auction::Command as AmmAuctionCommand;

/// A CLI for interacting with AMMAuctionSuapp Proof of Concept
#[derive(Debug, Parser)]
#[clap(name = "astria-cli", version)]
pub struct Cli {
    #[clap(subcommand)]
    pub command: Option<Command>,
}

impl Cli {
    /// Parse the command line arguments
    ///
    /// # Errors
    ///
    /// * If the arguments cannot be parsed
    pub fn get_args() -> eyre::Result<Self> {
        let args = Self::parse();
        Ok(args)
    }
}

/// Commands that can be run
#[derive(Debug, Subcommand)]
pub enum Command {
    AmmAuction {
        #[clap(subcommand)]
        command: AmmAuctionCommand,
    },
}
