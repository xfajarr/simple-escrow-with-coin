# Panduan Singkat Escrow & Mock Tokens

Instruksi step-by-step memakai modul `escrow_minimal` plus mock token (`MOCK_COIN`, `MOCK_TBTC`, `MOCK_ZSUI`) dan NFT contoh.

## 0. Build cepat (opsional)

```bash
sui move build
```

## 1. Publish package

```bash
sui client publish --gas-budget 100000000
# Catat PACKAGE_ID hasil publish, ganti <PKG> di perintah berikut.
```

## 2. Mint mock tokens (initializer otomatis saat publish)

Setiap modul mock punya `#[init]` yang jalan otomatis saat publish, membuat `TreasuryCap<T>` + metadata dan mengirimkannya ke publisher. Ambil object ID cap dari efek publish, lalu mint:

```bash
# Mint 1,000,000 MOCK_COIN
sui client call \
  --package <PKG> --module mock_coin --function mint_mock_coin \
  --args <TREASURY_CAP_MOCKCOIN_ID> 1000000 \
  --gas-budget 50000000

# Mint 0.01 TBTC (9 desimal → 10000000)
sui client call \
  --package <PKG> --module mock_tbtc --function mint_tbtc \
  --args <TREASURY_CAP_TBTC_ID> 10000000 \
  --gas-budget 50000000

# Mint 10 zSUI (9 desimal → 10000000000)
sui client call \
  --package <PKG> --module mock_zsui --function mint_zsui \
  --args <TREASURY_CAP_ZSUI_ID> 10000000000 \
  --gas-budget 50000000
```

## 3. Escrow koin fungible (1 jenis koin)

- `create_escrow<COIN>()`: seller kunci deposit, set `request_amount`.
- `accept_escrow<COIN>()`: buyer bayar pas jumlah, langsung terima deposit.
- `complete_escrow<COIN>()`: seller tarik pembayaran.
- `cancel_escrow<COIN>()`: seller batalkan (hanya kalau belum ada pembayaran).

Contoh memakai TBTC:

```bash
# Seller buat escrow: deposit 5e8 TBTC (0.5 TBTC), minta 8e8 TBTC
sui client call \
  --package <PKG> --module escrow_minimal --function create_escrow \
  --type-args <PKG>::mock_tbtc::MOCK_TBTC \
  --args <DEPOSIT_COIN_TBTC_ID> 800000000 \
  --gas-budget 50000000
# Simpan object ESCROW_ID

# Buyer accept: bayar 8e8 TBTC, terima deposit
sui client call \
  --package <PKG> --module escrow_minimal --function accept_escrow \
  --type-args <PKG>::mock_tbtc::MOCK_TBTC \
  --args <ESCROW_ID> <PAYMENT_COIN_TBTC_ID> \
  --gas-budget 50000000

# Seller complete: tarik pembayaran
sui client call \
  --package <PKG> --module escrow_minimal --function complete_escrow \
  --type-args <PKG>::mock_tbtc::MOCK_TBTC \
  --args <ESCROW_ID> \
  --gas-budget 30000000

# (opsional) Cancel sebelum ada pembayaran
sui client call \
  --package <PKG> --module escrow_minimal --function cancel_escrow \
  --type-args <PKG>::mock_tbtc::MOCK_TBTC \
  --args <ESCROW_ID> \
  --gas-budget 30000000
```

Ganti `--type-args` sesuai koin lain: `<PKG>::mock_coin::MOCK_COIN`, `<PKG>::mock_zsui::MOCK_ZSUI`, atau koin Anda sendiri.

## 4. Escrow NFT (bayar dengan 1 jenis koin)

- `create_nft_escrow<Coin, Nft>()`: seller kunci NFT, set `request_amount`.
- `accept_nft_escrow<Coin, Nft>()`: buyer bayar pas jumlah, langsung terima NFT.
- `complete_nft_escrow<Coin, Nft>()`: seller tarik pembayaran.
- `cancel_nft_escrow<Coin, Nft>()`: seller batalkan sebelum accept.

Mint NFT contoh:

```bash
sui client call \
  --package <PKG> --module escrow_minimal --function mint_mock_nft \
  --args b"Demo NFT" \
  --gas-budget 30000000
# Simpan NFT_ID
```

Contoh escrow NFT dibayar dengan zSUI:

```bash
# Seller buat escrow NFT, minta 5 zSUI (9 desimal → 5000000000)
sui client call \
  --package <PKG> --module escrow_minimal --function create_nft_escrow \
  --type-args <PKG>::mock_zsui::MOCK_ZSUI <PKG>::escrow_minimal::MockNft \
  --args <NFT_ID> 5000000000 \
  --gas-budget 50000000
# Simpan ESCROW_NFT_ID

# Buyer accept: bayar zSUI, terima NFT
sui client call \
  --package <PKG> --module escrow_minimal --function accept_nft_escrow \
  --type-args <PKG>::mock_zsui::MOCK_ZSUI <PKG>::escrow_minimal::MockNft \
  --args <ESCROW_NFT_ID> <PAYMENT_COIN_ZSUI_ID> \
  --gas-budget 50000000

# Seller complete: tarik pembayaran
sui client call \
  --package <PKG> --module escrow_minimal --function complete_nft_escrow \
  --type-args <PKG>::mock_zsui::MOCK_ZSUI <PKG>::escrow_minimal::MockNft \
  --args <ESCROW_NFT_ID> \
  --gas-budget 30000000

# (opsional) Cancel sebelum accept
sui client call \
  --package <PKG> --module escrow_minimal --function cancel_nft_escrow \
  --type-args <PKG>::mock_zsui::MOCK_ZSUI <PKG>::escrow_minimal::MockNft \
  --args <ESCROW_NFT_ID> \
  --gas-budget 30000000
```

## 5. Catatan

- Escrow ini hanya mendukung satu jenis koin per escrow (deposit dan pembayaran tipe sama). Jika perlu deposit SUI bayar USDC, perlu modul baru dengan dua tipe koin.
- Mock token memakai `#[init]` + `coin_registry::new_currency_with_otw`, jadi tidak perlu panggil init manual setelah publish.
- Pastikan `request_amount` sama persis dengan `coin::value(payment)` saat accept, atau transaksi abort (error 0).
- Fungsi `complete_*`/`cancel_*` hanya bisa dipanggil creator escrow (abort 2/3).
