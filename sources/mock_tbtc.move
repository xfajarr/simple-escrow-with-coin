module escrow::mock_tbtc {
    use sui::coin;
    use sui::coin::TreasuryCap;
    use sui::coin_registry;
    use sui::tx_context::TxContext;
    use sui::transfer;

    /// One-time witness untuk token mock TBTC (juga tipe koin).
    public struct MOCK_TBTC has drop {}

    /// Initializer otomatis saat publish: buat TBTC dan serahkan kapabilitas ke publisher.
    fun init(witness: MOCK_TBTC, ctx: &mut TxContext) {
        let (builder, cap) = coin_registry::new_currency_with_otw(
            witness,
            9,
            b"TBTC".to_string(),
            b"Mock TBTC".to_string(),
            b"Mock Bitcoin on Sui".to_string(),
            b"".to_string(),
            ctx,
        );
        // let metadata_cap = coin_registry::finalize(builder, ctx);
        let metadata_cap = builder.finalize(ctx);
        transfer::public_transfer(cap, ctx.sender());
        transfer::public_transfer(metadata_cap, ctx.sender());
    }

    /// Mint TBTC ke caller.
    public entry fun mint_tbtc(
        cap: &mut TreasuryCap<MOCK_TBTC>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        let minted = coin::mint(cap, amount, ctx);
        transfer::public_transfer(minted, ctx.sender());
    }
}
