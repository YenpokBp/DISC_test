const mysql = require("mysql2");

const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "disc_test",
});

db.connect((err) => {
  if (err) {
    console.error("Koneksi database gagal:", err);
    return;
  }

  console.log("MySQL berhasil terhubung!");
});

module.exports = db;
