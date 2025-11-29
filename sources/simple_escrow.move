module escrow::simple_escrow {
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;

    /// Escrow untuk swap antara dua tipe koin berbeda.
    /// DepositCoinType: tipe koin yang di-deposit oleh seller
    /// PaymentCoinType: tipe koin yang harus dibayar oleh buyer
    public struct Escrow<phantom DepositCoinType: store, phantom PaymentCoinType: store> has key, store {
        id: object::UID,
        deposit: Balance<DepositCoinType>,
        requested_amount: u64,
        receive: Balance<PaymentCoinType>,
        creator: address,
    }

    /// Seller kunci koin miliknya (DepositCoinType), tentukan jumlah PaymentCoinType yang diminta dari buyer.
    /// Contoh: Seller deposit TBTC, minta zSUI sebagai pembayaran.
    public entry fun create_escrow<DepositCoinType: store, PaymentCoinType: store>(
        deposit_coin: Coin<DepositCoinType>,
        request_amount: u64,
        ctx: &mut TxContext,
    ) {
        let escrow = Escrow<DepositCoinType, PaymentCoinType> {
            id: object::new(ctx),
            deposit: coin::into_balance(deposit_coin),
            requested_amount: request_amount,
            receive: balance::zero<PaymentCoinType>(),
            creator: ctx.sender(),
        };

        transfer::public_transfer(escrow, ctx.sender());
    }

    /// Buyer kirim koin PaymentCoinType sesuai request, langsung menerima deposit DepositCoinType dari seller.
    /// Contoh: Buyer bayar zSUI, terima TBTC dari escrow.
    public entry fun accept_escrow<DepositCoinType: store, PaymentCoinType: store>(
        escrow: &mut Escrow<DepositCoinType, PaymentCoinType>,
        payment: Coin<PaymentCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(coin::value(&payment) == escrow.requested_amount, 0);

        balance::join(&mut escrow.receive, coin::into_balance(payment));
        let deposit_balance = balance::withdraw_all(&mut escrow.deposit);
        let deposit_coin = coin::from_balance(deposit_balance, ctx);
        transfer::public_transfer(deposit_coin, ctx.sender());
    }

    /// Seller tarik pembayaran PaymentCoinType yang sudah diterima dari buyer.
    public entry fun complete_escrow<DepositCoinType: store, PaymentCoinType: store>(
        escrow: &mut Escrow<DepositCoinType, PaymentCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(ctx.sender() == escrow.creator, 2);
        let receive_balance = balance::withdraw_all(&mut escrow.receive);
        let payout = coin::from_balance(receive_balance, ctx);
        transfer::public_transfer(payout, ctx.sender());
    }

    /// Seller batalkan escrow, deposit dikembalikan ke seller.
    /// Hanya bisa dibatalkan jika belum ada pembayaran dari buyer.
    public entry fun cancel_escrow<DepositCoinType: store, PaymentCoinType: store>(
        escrow: Escrow<DepositCoinType, PaymentCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(ctx.sender() == escrow.creator, 3);

        let Escrow {
            id,
            mut deposit,
            mut receive,
            requested_amount: _,
            creator: _,
        } = escrow;

        // Pastikan tidak ada pembayaran yang tertahan
        let recv_all = balance::withdraw_all(&mut receive);
        balance::destroy_zero(recv_all);
        balance::destroy_zero(receive);

        let deposit_all = balance::withdraw_all(&mut deposit);
        balance::destroy_zero(deposit);
        let coin_out = coin::from_balance(deposit_all, ctx);
        object::delete(id);
        transfer::public_transfer(coin_out, ctx.sender());
    }
}
