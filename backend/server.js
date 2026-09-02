const express = require("express");
const cors = require("cors");
const db = require("./db");

const app = express();

app.use(cors());
app.use(express.json());

// ==========================================
// HALAMAN UTAMA & TEST KONEKSI
// ==========================================

app.get("/", (req, res) => {
  res.send("Server DISC berhasil berjalan!");
});

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
// 1. MENGAMBIL SEMUA 24 SOAL + 4 PILIHAN (Sekaligus)
// ==========================================
app.get("/questions", (req, res) => {
  const sql = `
    SELECT 
      q.id AS question_id,
      q.nomor,
      o.id AS option_id,
      o.option_order,
      o.teks
    FROM questions q
    JOIN options o ON q.id = o.question_id
    ORDER BY q.nomor, o.option_order
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("Error mengambil questions:", err);
      return res.status(500).json({
        success: false,
        message: "Gagal mengambil daftar pertanyaan",
        error: err.message,
      });
    }

    // Kelompokkan opsi ke dalam masing-masing nomor soal
    const formattedData = [];
    results.forEach((row) => {
      let q = formattedData.find(
        (item) => item.question_id === row.question_id,
      );
      if (!q) {
        q = {
          question_id: row.question_id,
          nomor: row.nomor,
          options: [],
        };
        formattedData.push(q);
      }
      q.options.push({
        option_id: row.option_id,
        order: row.option_order,
        teks: row.teks,
      });
    });

    res.json({
      success: true,
      data: formattedData,
    });
  });
});

// ==========================================
// 2. MENGAMBIL 1 SOAL TERTENTU (Step-by-Step)
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
      o.teks
    FROM questions q
    JOIN options o ON q.id = o.question_id
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
// 3. SUBMIT TES: SIMPAN JAWABAN & HITUNG SKOR
// ==========================================
app.post("/submit-test", (req, res) => {
  const { user, answers } = req.body;

  // Validasi input
  if (!user || !answers || answers.length !== 24) {
    return res.status(400).json({
      success: false,
      message: "Data peserta atau 24 nomor jawaban belum lengkap",
    });
  }

  // A. Simpan User
  const sqlUser = `
    INSERT INTO users (nama_lengkap, umur, pendidikan_terakhir, pekerjaan, jenis_kelamin)
    VALUES (?, ?, ?, ?, ?)
  `;
  const userParams = [
    user.nama_lengkap,
    user.umur,
    user.pendidikan_terakhir,
    user.pekerjaan,
    user.jenis_kelamin,
  ];

  db.query(sqlUser, userParams, (errUser, resUser) => {
    if (errUser) {
      console.error("Gagal simpan user:", errUser);
      return res
        .status(500)
        .json({ success: false, message: "Gagal menyimpan data user" });
    }

    const userId = resUser.insertId;

    // B. Buat Attempt
    const sqlAttempt = `INSERT INTO attempts (user_id, status) VALUES (?, 'in_progress')`;
    db.query(sqlAttempt, [userId], (errAttempt, resAttempt) => {
      if (errAttempt) {
        console.error("Gagal simpan attempt:", errAttempt);
        return res
          .status(500)
          .json({ success: false, message: "Gagal membuat sesi tes" });
      }

      const attemptId = resAttempt.insertId;

      // C. Siapkan Array 24 Jawaban
      const answerRows = answers.map((ans) => [
        attemptId,
        ans.question_id,
        ans.most_option_id,
        ans.least_option_id,
      ]);

      const sqlAnswers = `
        INSERT INTO answers (attempt_id, question_id, most_option_id, least_option_id)
        VALUES ?
      `;

      db.query(sqlAnswers, [answerRows], (errAns) => {
        if (errAns) {
          console.error("Gagal simpan jawaban:", errAns);
          return res
            .status(500)
            .json({ success: false, message: "Gagal menyimpan jawaban" });
        }

        // D. Panggil Stored Procedure Hitung Skor DISC
        db.query("CALL CalculateDiscScores(?)", [attemptId], (errCalc) => {
          if (errCalc) {
            console.error("Gagal hitung skor:", errCalc);
            return res
              .status(500)
              .json({ success: false, message: "Gagal menghitung skor tes" });
          }

          // E. Ambil Hasil Akhir
          const sqlResult = `
            SELECT 
              r.*,
              u.nama_lengkap
            FROM results r
            JOIN attempts a ON r.attempt_id = a.id
            JOIN users u ON a.user_id = u.id
            WHERE r.attempt_id = ?
          `;

          db.query(sqlResult, [attemptId], (errRes, rowsRes) => {
            if (errRes || rowsRes.length === 0) {
              console.error("Gagal mengambil hasil:", errRes);
              return res
                .status(500)
                .json({ success: false, message: "Gagal memuat hasil tes" });
            }

            res.json({
              success: true,
              message: "Tes berhasil diselesaikan",
              attempt_id: attemptId,
              result: rowsRes[0],
            });
          });
        });
      });
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
