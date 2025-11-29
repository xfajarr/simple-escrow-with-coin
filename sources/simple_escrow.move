module escrow::simple_escrow {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    /// Escrow untuk swap antara dua tipe koin berbeda.
    public struct Escrow<phantom DepositCoinType, phantom PaymentCoinType> has key, store {
        id: UID,
        deposit: Balance<DepositCoinType>,
        requested_amount: u64,
        receive: Balance<PaymentCoinType>,
        creator: address,
    }

    /// Seller deposit koin dan tentukan jumlah pembayaran yang diminta.
    public entry fun create_escrow<DepositCoinType, PaymentCoinType>(
        deposit_coin: Coin<DepositCoinType>,
        request_amount: u64,
        ctx: &mut TxContext,
    ) {
        let escrow = Escrow<DepositCoinType, PaymentCoinType> {
            id: object::new(ctx),
            deposit: deposit_coin.into_balance(),
            requested_amount: request_amount,
            receive: balance::zero(),
            creator: ctx.sender(),
        };
        transfer::public_transfer(escrow, ctx.sender());
    }

    /// Buyer bayar dan terima deposit.
    /// Buyer bisa kirim coin >= requested_amount, sisa akan di-refund otomatis.
    public entry fun accept_escrow<DepositCoinType, PaymentCoinType>(
        escrow: &mut Escrow<DepositCoinType, PaymentCoinType>,
        mut payment: Coin<PaymentCoinType>,
        ctx: &mut TxContext,
    ) {
        let payment_value = payment.value();
        assert!(payment_value >= escrow.requested_amount, 0);

        // Split exact amount, refund sisanya
        let exact_payment = payment.split(escrow.requested_amount, ctx);
        if (payment.value() > 0) {
            transfer::public_transfer(payment, ctx.sender()); // refund sisa
        } else {
            payment.destroy_zero(); // tidak ada sisa
        };

        // Simpan pembayaran di escrow
        escrow.receive.join(exact_payment.into_balance());

        // Transfer deposit ke buyer
        transfer::public_transfer(coin::from_balance(escrow.deposit.withdraw_all(), ctx), ctx.sender());
    }

    /// Seller tarik pembayaran yang diterima.
    public entry fun complete_escrow<DepositCoinType, PaymentCoinType>(
        escrow: &mut Escrow<DepositCoinType, PaymentCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(ctx.sender() == escrow.creator, 1);
        transfer::public_transfer(coin::from_balance(escrow.receive.withdraw_all(), ctx), ctx.sender());
    }

    /// Seller batalkan escrow (hanya jika belum ada pembayaran).
    public entry fun cancel_escrow<DepositCoinType, PaymentCoinType>(
        escrow: Escrow<DepositCoinType, PaymentCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(ctx.sender() == escrow.creator, 2);
        let Escrow { id, deposit, requested_amount: _, receive, creator: _ } = escrow;
        receive.destroy_zero(); // Fails if buyer already paid
        object::delete(id);
        transfer::public_transfer(coin::from_balance(deposit, ctx), ctx.sender());
    }
}