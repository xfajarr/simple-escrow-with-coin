// #[test_only]
// module escrow::escrow_tests {
//     use escrow::escrow_best_practice;
//     use escrow::escrow_best_practice::Escrow as BestEscrow;
//     use escrow::escrow_minimal;
//     use escrow::escrow_minimal::Escrow as MinimalEscrow;
//     use sui::coin::{Self as coin};
//     use sui::sui::SUI;
//     use sui::test_scenario as ts;

//     const SELLER: address = @0x1;
//     const BUYER: address = @0x2;
//     const STRANGER: address = @0x3;

//     fun mint_sui(scenario: &mut ts::Scenario, amount: u64): coin::Coin<SUI> {
//         coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
//     }

//     #[test]
//     fun minimal_create_and_cancel_returns_deposit() {
//         let mut scenario = ts::begin(SELLER);

//         // Create escrow then cancel before anyone accepts
//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let deposit = mint_sui(&mut scenario, 1_000);
//             escrow_minimal::create_escrow(deposit, 600, ts::ctx(&mut scenario));
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let escrow_obj = ts::take_from_sender<MinimalEscrow>(&scenario);
//             escrow_minimal::cancel_escrow(escrow_obj, ts::ctx(&mut scenario));
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let returned = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
//             assert!(coin::value(&returned) == 1_000, 0);
//             ts::return_to_sender(&scenario, returned);
//         };

//         ts::end(scenario);
//     }

//     #[test]
//     fun minimal_accept_and_complete_flow() {
//         let mut scenario = ts::begin(SELLER);

//         // Seller posts escrow
//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let deposit = mint_sui(&mut scenario, 1_000);
//             escrow_minimal::create_escrow(deposit, 600, ts::ctx(&mut scenario));
//         };

//         // Transfer escrow object to buyer so they can accept
//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let escrow_obj = ts::take_from_sender<MinimalEscrow>(&scenario);
//             sui::transfer::public_transfer(escrow_obj, BUYER);
//         };

//         // Buyer pays and receives the deposit
//         ts::next_tx(&mut scenario, BUYER);
//         {
//             let mut escrow_obj = ts::take_from_sender<MinimalEscrow>(&scenario);
//             let payment = mint_sui(&mut scenario, 600);
//             escrow_minimal::accept_escrow(&mut escrow_obj, payment, ts::ctx(&mut scenario));

//             // Hand the escrow back to the seller to complete
//             sui::transfer::public_transfer(escrow_obj, SELLER);
//         };

//         // Buyer cek deposit yang diterima
//         ts::next_tx(&mut scenario, BUYER);
//         {
//             let received_coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
//             assert!(coin::value(&received_coin) == 1_000, 0);
//             ts::return_to_sender(&scenario, received_coin);
//         };

//         // Seller completes and gets the buyer's payment
//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let mut escrow_obj = ts::take_from_sender<MinimalEscrow>(&scenario);
//             escrow_minimal::complete_escrow(&mut escrow_obj, ts::ctx(&mut scenario));
//             ts::return_to_sender(&scenario, escrow_obj);
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let payout = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
//             assert!(coin::value(&payout) == 600, 1);
//             ts::return_to_sender(&scenario, payout);
//         };

//         ts::end(scenario);
//     }

//     #[test]
//     fun best_practice_accept_and_complete_with_status() {
//         let mut scenario = ts::begin(SELLER);

//         // Seller posts escrow with stricter best-practice module
//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let deposit = mint_sui(&mut scenario, 1_200);
//             escrow_best_practice::create(deposit, 800, ts::ctx(&mut scenario));
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let escrow_obj = ts::take_from_sender<BestEscrow>(&scenario);
//             assert!(escrow_best_practice::is_active(&escrow_obj), 0);
//             assert!(escrow_best_practice::get_deposit_amount(&escrow_obj) == 1_200, 1);
//             assert!(escrow_best_practice::get_requested_amount(&escrow_obj) == 800, 2);
//             assert!(escrow_best_practice::get_received_amount(&escrow_obj) == 0, 3);

//             sui::transfer::public_transfer(escrow_obj, BUYER);
//         };

//         ts::next_tx(&mut scenario, BUYER);
//         {
//             let mut escrow_obj = ts::take_from_sender<BestEscrow>(&scenario);
//             let payment = mint_sui(&mut scenario, 800);
//             escrow_best_practice::accept(&mut escrow_obj, payment, ts::ctx(&mut scenario));

//             assert!(escrow_best_practice::is_accepted(&escrow_obj), 0);

//             sui::transfer::public_transfer(escrow_obj, SELLER);
//         };

//         ts::next_tx(&mut scenario, BUYER);
//         {
//             let deposit_coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
//             assert!(coin::value(&deposit_coin) == 1_200, 1);
//             ts::return_to_sender(&scenario, deposit_coin);
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let mut escrow_obj = ts::take_from_sender<BestEscrow>(&scenario);
//             escrow_best_practice::complete(&mut escrow_obj, ts::ctx(&mut scenario));

//             assert!(escrow_best_practice::is_completed(&escrow_obj), 0);
//             ts::return_to_sender(&scenario, escrow_obj);
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let payout = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
//             assert!(coin::value(&payout) == 800, 1);
//             ts::return_to_sender(&scenario, payout);
//         };

//         ts::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 2, location = escrow::escrow_best_practice)] // ENotCreator
//     fun best_practice_only_creator_can_cancel() {
//         let mut scenario = ts::begin(SELLER);

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let deposit = mint_sui(&mut scenario, 500);
//             escrow_best_practice::create(deposit, 200, ts::ctx(&mut scenario));
//         };

//         ts::next_tx(&mut scenario, SELLER);
//         {
//             let escrow_obj = ts::take_from_sender<BestEscrow>(&scenario);
//             sui::transfer::public_transfer(escrow_obj, STRANGER);
//         };

//         ts::next_tx(&mut scenario, STRANGER);
//         {
//             let escrow_obj = ts::take_from_sender<BestEscrow>(&scenario);
//             escrow_best_practice::cancel(escrow_obj, ts::ctx(&mut scenario));
//         };

//         ts::end(scenario);
//     }
// }
