use std::process::ExitCode;

use auction_cli_server::{cli::Cli, commands};
use color_eyre::eyre::{self, Context};
use suave_rust::{amm_auction_config::AmmAuctionConfig, amm_auction_suapp::AmmAuctionSuapp};

fn main() -> ExitCode {
    if let Err(err) = run() {
        eprintln!("{err:?}");
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}

// Run our asynchronous command code in a blocking manner
fn run() -> eyre::Result<()> {
    let rt = tokio::runtime::Runtime::new().wrap_err("failed to create a new runtime")?;

    rt.block_on(async_main())
}

async fn async_main() -> eyre::Result<()> {
    let config = AmmAuctionConfig::new("../poc_first_swap_auction/.env")
        .await
        .expect("failed to build auction amm config");

    let amm_auction_wrapper = AmmAuctionSuapp::new_from_config(config)
        .await
        .wrap_err("failed to build amm auction suapp wrapper")?;

    let args = Cli::get_args()?;
    commands::run(args, amm_auction_wrapper).await?;
    Ok(())
}
