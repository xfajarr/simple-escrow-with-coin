// module escrow::escrow_best_practice {
//     use sui::balance;
//     use sui::balance::Balance;
//     use sui::coin;
//     use sui::coin::Coin;
//     use sui::event;
//     use sui::object;
//     use sui::sui::SUI;

//     // ============== Error Codes ==============
//     const EInvalidAmount: u64 = 0;
//     const EEscrowNotActive: u64 = 1;
//     const ENotCreator: u64 = 2;
//     const EEscrowNotAccepted: u64 = 3;

//     // ============== Status Constants ==============
//     const STATUS_ACTIVE: u8 = 0;
//     const STATUS_ACCEPTED: u8 = 1;
//     const STATUS_COMPLETED: u8 = 2;

//     /// Escrow object dengan status tracking (SUI only)
//     public struct Escrow has key, store {
//         id: object::UID,
//         deposit: Balance<SUI>,
//         requested_amount: u64,
//         receive: Balance<SUI>,
//         creator: address,
//         acceptor: address,
//         status: u8,
//         created_at: u64,
//         accepted_at: u64,
//         completed_at: u64,
//     }

//     // ============== Events ==============
//     public struct EscrowCreated has copy, drop {
//         escrow_id: object::ID,
//         creator: address,
//         deposit_amount: u64,
//         requested_amount: u64,
//     }

//     public struct EscrowAccepted has copy, drop {
//         escrow_id: object::ID,
//         acceptor: address,
//         amount: u64,
//     }

//     public struct EscrowCompleted has copy, drop {
//         escrow_id: object::ID,
//         creator: address,
//         amount: u64,
//     }

//     public struct EscrowCancelled has copy, drop {
//         escrow_id: object::ID,
//         creator: address,
//         amount: u64,
//     }

//     // ============== Helpers ==============
//     fun extract_deposit(escrow: &mut Escrow): Balance<SUI> {
//         balance::withdraw_all(&mut escrow.deposit)
//     }

//     fun extract_receive(escrow: &mut Escrow): Balance<SUI> {
//         balance::withdraw_all(&mut escrow.receive)
//     }

//     // ============== Core Internal ==============
//     fun create_internal(
//         deposit_coin: Coin<SUI>,
//         request_amount: u64,
//         ctx: &mut sui::tx_context::TxContext,
//     ): Escrow {
//         let sender = ctx.sender();
//         let deposit_amount = coin::value(&deposit_coin);

//         assert!(deposit_amount > 0, EInvalidAmount);
//         assert!(request_amount > 0, EInvalidAmount);

//         // Simpan deposit seller dan target permintaan buyer
//         let escrow = Escrow {
//             id: object::new(ctx),
//             deposit: coin::into_balance(deposit_coin),
//             requested_amount: request_amount,
//             receive: balance::zero<SUI>(),
//             creator: sender,
//             acceptor: @0x0,
//             status: STATUS_ACTIVE,
//             created_at: ctx.epoch_timestamp_ms(),
//             accepted_at: 0,
//             completed_at: 0,
//         };

//         let escrow_id = object::id(&escrow);
//         event::emit(EscrowCreated {
//             escrow_id,
//             creator: sender,
//             deposit_amount,
//             requested_amount: request_amount,
//         });

//         escrow
//     }

//     fun accept_internal(
//         escrow: &mut Escrow,
//         payment: Coin<SUI>,
//         ctx: &mut sui::tx_context::TxContext,
//     ): Coin<SUI> {
//         let sender = ctx.sender();
//         let payment_value = coin::value(&payment);

//         assert!(payment_value == escrow.requested_amount, EInvalidAmount);
//         assert!(escrow.status == STATUS_ACTIVE, EEscrowNotActive);

//         balance::join(&mut escrow.receive, coin::into_balance(payment));
//         escrow.status = STATUS_ACCEPTED;
//         escrow.acceptor = sender;
//         escrow.accepted_at = ctx.epoch_timestamp_ms();

//         // Deposit seller berpindah ke buyer
//         let deposit_balance = extract_deposit(escrow);
//         let deposit_coin = coin::from_balance(deposit_balance, ctx);

//         let escrow_id = object::id(escrow);
//         event::emit(EscrowAccepted {
//             escrow_id,
//             acceptor: sender,
//             amount: payment_value,
//         });

//         deposit_coin
//     }

//     fun complete_internal(
//         escrow: &mut Escrow,
//         ctx: &mut sui::tx_context::TxContext,
//     ): Coin<SUI> {
//         let sender = ctx.sender();

//         assert!(sender == escrow.creator, ENotCreator);
//         assert!(escrow.status == STATUS_ACCEPTED, EEscrowNotAccepted);

//         let receive_balance = extract_receive(escrow);
//         let payout = coin::from_balance(receive_balance, ctx);

//         escrow.status = STATUS_COMPLETED;
//         escrow.completed_at = ctx.epoch_timestamp_ms();

//         let escrow_id = object::id(escrow);
//         event::emit(EscrowCompleted {
//             escrow_id,
//             creator: sender,
//             amount: coin::value(&payout),
//         });

//         payout
//     }

//     fun cancel_internal(
//         escrow: Escrow,
//         ctx: &mut sui::tx_context::TxContext,
//     ): Coin<SUI> {
//         let sender = ctx.sender();
//         let escrow_id = object::id(&escrow);

//         assert!(escrow.creator == sender, ENotCreator);
//         assert!(escrow.status == STATUS_ACTIVE, EEscrowNotActive);

//         let Escrow {
//             id,
//             deposit,
//             receive,
//             requested_amount: _,
//             creator: _,
//             acceptor: _,
//             status: _,
//             created_at: _,
//             accepted_at: _,
//             completed_at: _,
//         } = escrow;

//         // Belum ada yang accept, deposit kembali ke seller
//         let coin_a = coin::from_balance(deposit, ctx);
//         let amount = coin::value(&coin_a);

//         balance::destroy_zero(receive);
//         object::delete(id);

//         event::emit(EscrowCancelled {
//             escrow_id,
//             creator: sender,
//             amount,
//         });

//         coin_a
//     }

//     // ============== Entry APIs (semua public = entry) ==============
//     public entry fun create(
//         deposit_coin: Coin<SUI>,
//         request_amount: u64,
//         ctx: &mut sui::tx_context::TxContext,
//     ) {
//         let escrow = create_internal(deposit_coin, request_amount, ctx);
//         sui::transfer::public_transfer(escrow, ctx.sender());
//     }

//     public entry fun accept(
//         escrow: &mut Escrow,
//         payment: Coin<SUI>,
//         ctx: &mut sui::tx_context::TxContext,
//     ) {
//         sui::transfer::public_transfer(accept_internal(escrow, payment, ctx), ctx.sender());
//     }

//     public entry fun complete(
//         escrow: &mut Escrow,
//         ctx: &mut sui::tx_context::TxContext,
//     ) {
//         sui::transfer::public_transfer(complete_internal(escrow, ctx), ctx.sender());
//     }

//     public entry fun cancel(
//         escrow: Escrow,
//         ctx: &mut sui::tx_context::TxContext,
//     ) {
//         sui::transfer::public_transfer(cancel_internal(escrow, ctx), ctx.sender());
//     }

//     // ============== Views ==============
//     public fun get_creator(escrow: &Escrow): address {
//         escrow.creator
//     }

//     public fun get_acceptor(escrow: &Escrow): address {
//         escrow.acceptor
//     }

//     public fun get_deposit_amount(escrow: &Escrow): u64 {
//         balance::value(&escrow.deposit)
//     }

//     public fun get_requested_amount(escrow: &Escrow): u64 {
//         escrow.requested_amount
//     }

//     public fun get_received_amount(escrow: &Escrow): u64 {
//         balance::value(&escrow.receive)
//     }

//     public fun get_status(escrow: &Escrow): u8 {
//         escrow.status
//     }

//     public fun is_active(escrow: &Escrow): bool {
//         escrow.status == STATUS_ACTIVE
//     }

//     public fun is_accepted(escrow: &Escrow): bool {
//         escrow.status == STATUS_ACCEPTED
//     }

//     public fun is_completed(escrow: &Escrow): bool {
//         escrow.status == STATUS_COMPLETED
//     }

//     public fun get_created_at(escrow: &Escrow): u64 {
//         escrow.created_at
//     }

//     public fun get_accepted_at(escrow: &Escrow): u64 {
//         escrow.accepted_at
//     }

//     public fun get_completed_at(escrow: &Escrow): u64 {
//         escrow.completed_at
//     }

//     public fun view(
//         escrow: &Escrow,
//     ): (address, address, u64, u64, u64, u8, u64, u64, u64) {
//         (
//             escrow.creator,
//             escrow.acceptor,
//             balance::value(&escrow.deposit),
//             escrow.requested_amount,
//             balance::value(&escrow.receive),
//             escrow.status,
//             escrow.created_at,
//             escrow.accepted_at,
//             escrow.completed_at,
//         )
//     }
// }
