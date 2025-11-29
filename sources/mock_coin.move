module escrow::mock_coin {
    use sui::coin;
    use sui::coin::TreasuryCap;
    use sui::coin_registry;
    use sui::tx_context::TxContext;
    use sui::transfer;

    /// One-time witness untuk mock fungible token (juga tipe koin).
    public struct MOCK_COIN has drop {}

    /// Initializer otomatis saat publish: buat koin, metadata, dan serahkan kapabilitas ke publisher.
    fun init(witness: MOCK_COIN, ctx: &mut TxContext) {
        let (builder, cap) = coin_registry::new_currency_with_otw(
            witness,
            9,
            b"MOCK".to_string(),
            b"Mock Coin".to_string(),
            b"Mock coin for escrow demo".to_string(),
            b"".to_string(),
            ctx,
        );
        let metadata_cap = coin_registry::finalize(builder, ctx);
        transfer::public_transfer(cap, ctx.sender());
        transfer::public_transfer(metadata_cap, ctx.sender());
    }

    /// Mint mock coin ke sender.
    public entry fun mint_mock_coin(
        cap: &mut TreasuryCap<MOCK_COIN>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        let minted = coin::mint(cap, amount, ctx);
        transfer::public_transfer(minted, ctx.sender());
    }
}
