mod amm_auction;

use color_eyre::{
    eyre,
    eyre::eyre,
};
use suave_rust::amm_auction_suapp::AmmAuctionSuapp;

use crate::cli::{
    amm_auction::Command as AmmAuctionCommand,
    Cli,
    Command,
};

/// Checks what function needs to be run and calls it with the appropriate arguments
///
/// # Arguments
///
/// * `cli` - The arguments passed to the command
///
/// # Errors
///
/// * If no command is specified
///
/// # Panics
///
/// * If the command is not recognized
pub async fn run(cli: Cli, mut amm_auction: AmmAuctionSuapp) -> eyre::Result<()> {
    if let Some(command) = cli.command {
        match command {
            Command::AmmAuction {
                command,
            } => match command {
                AmmAuctionCommand::Auction(args) => {
                    amm_auction::trigger_auction(&args, &mut amm_auction).await?
                }
                AmmAuctionCommand::Bid(args) => {
                    amm_auction::send_bid(&args, &mut amm_auction).await?
                }
                AmmAuctionCommand::SwapTx(args) => {
                    amm_auction::send_swap_tx(&args, &mut amm_auction).await?
                }
                AmmAuctionCommand::InitializeSuapp(args) => {
                    amm_auction::initialize_suapp(&args, &mut amm_auction).await?
                }
            },
        }
    } else {
        return Err(eyre!("Error: No command specified"));
    }
    Ok(())
}
