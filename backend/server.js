const express = require("express");
const cors = require("cors");

const db = require("./db");

const app = express();

app.use(cors());
app.use(express.json());

// ==========================================
// HALAMAN UTAMA
// ==========================================

app.get("/", (req, res) => {
  res.send("Server DISC berhasil berjalan!");
});

// ==========================================
// TEST KONEKSI DATABASE
// ==========================================

app.get("/test-db", (req, res) => {
  db.query("SELECT 1 AS test", (err, results) => {
    if (err) {
      console.error("Database error:", err);

      return res.status(500).json({
        success: false,
        message: "Database gagal terhubung",
        error: err.message,
      });
    }

    res.json({
      success: true,
      message: "Database berhasil terhubung!",
      data: results,
    });
  });
});

// ==========================================
// MENGAMBIL SEMUA PERTANYAAN
// ==========================================

app.get("/questions", (req, res) => {
  const sql = `
    SELECT *
    FROM questions
    ORDER BY nomor
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("Error mengambil questions:", err);

      return res.status(500).json({
        success: false,
        message: "Gagal mengambil pertanyaan",
        error: err.message,
      });
    }

    res.json({
      success: true,
      data: results,
    });
  });
});

// ==========================================
// MENGAMBIL 1 SOAL + 4 PILIHAN
// ==========================================

app.get("/questions/:nomor", (req, res) => {
  const nomor = req.params.nomor;

  const sql = `
    SELECT
      q.id AS question_id,
      q.nomor,
      q.pertanyaan,

      o.id AS option_id,
      o.option_order,
      o.teks,
      o.most_type,
      o.least_type

    FROM questions q

    JOIN options o
      ON q.id = o.question_id

    WHERE q.nomor = ?

    ORDER BY o.option_order
  `;

  db.query(sql, [nomor], (err, results) => {
    if (err) {
      console.error("Error mengambil soal:", err);

      return res.status(500).json({
        success: false,
        message: "Gagal mengambil soal",
        error: err.message,
      });
    }

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Soal tidak ditemukan",
      });
    }

    res.json({
      success: true,
      data: results,
    });
  });
});

// ==========================================
// MENJALANKAN SERVER
// ==========================================

app.listen(3000, () => {
  console.log("----------------------------------");
  console.log("Server DISC berhasil dijalankan!");
  console.log("http://localhost:3000");
  console.log("----------------------------------");
});
