.pragma library

// Local presentation registry for the first Settings shell.
// Backend catalog loading can replace this provider without changing SettingsPage.
function getSections() {
    return [
        {
            code: "operations",
            title: "OPERASIONAL",
            description: "Master data dan konfigurasi kegiatan usaha.",
            modules: [
                { code: "inventory", title: "Bahan Baku & Persediaan",
                  description: "Master bahan baku, satuan, saldo awal, dan import CSV/Excel.",
                  detail: "Modul ini menjadi tempat onboarding bahan baku dan saldo awal persediaan. Import akan menggunakan template yang dapat diunduh, preview, validasi per baris, dan konfirmasi sebelum membuat dokumen saldo awal." },
                { code: "production_machines", title: "Mesin Produksi",
                  description: "Master mesin, overhead operasional, dan penyusutan aset.",
                  detail: "Kelola Mixer, Press Baglog, Steamer, Autoclave, dan Pompa Sprayer. Tarif overhead ditentukan per mesin dan dapat memakai basis estimasi baglog, baglog aktual, durasi, siklus, konsumsi aktual, atau input manual." },
                { code: "kumbungs", title: "Kumbung",
                  description: "Nama, lokasi, pemilik, dan kapasitas kumbung.",
                  detail: "Kelola master kumbung per lokasi. Kapasitas terpakai akan dihitung dari ledger penempatan, bukan angka okupansi yang diedit manual." },
                { code: "production_recipes", title: "Preset Adonan",
                  description: "Formula berbasis bahan baku utama dan estimasi hasil mixing.",
                  detail: "Pilih satu bahan utama sebagai basis formula. Takaran bahan lain dan estimasi hasil baglog dihitung proporsional. Estimasi hanya berlaku pada Mixing dan tidak membuat stok baglog." }
            ]
        },
        {
            code: "devices",
            title: "PERANGKAT",
            description: "Integrasi perangkat keras dan otomasi.",
            modules: [
                { code: "fingerprint", title: "Mesin Fingerprint",
                  description: "Konfigurasi perangkat absensi dan sinkronisasi.",
                  detail: "Ruang pengaturan perangkat fingerprint. Koneksi, kredensial, sinkronisasi, dan log perangkat akan dikelola melalui adapter dan penyimpanan rahasia yang aman." },
                { code: "iot", title: "IoT",
                  description: "Sensor, gateway, perangkat, dan otomasi lokal.",
                  detail: "Ruang pengaturan perangkat IoT. Otomasi lokal harus tetap berjalan ketika koneksi internet atau cloud terputus." }
            ]
        },
        {
            code: "interface",
            title: "ANTARMUKA",
            description: "Preferensi tampilan aplikasi.",
            modules: [
                { code: "appearance", title: "Preferensi Antarmuka",
                  description: "Ukuran huruf, kepadatan, dan preferensi tampilan lanjutan.",
                  detail: "Pengaturan ukuran huruf, kepadatan, dan preferensi tampilan lanjutan. Tema aplikasi dikelola melalui menu Tema Aplikasi. Preferensi ini disimpan per pengguna atau per tenant sesuai cakupan pengaturannya." }
            ]
        }
    ]
}
