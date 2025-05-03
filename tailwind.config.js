module.exports = {
  content: [
    "./layouts/**/*.html", // semua layout
    "./content/**/*.md", // semua konten markdown
    "./themes/**/*.{html,js}", // kalau pakai tema custom
    "./assets/js/**/*.js", // kalau pakai interaktivitas js
    "./index.html", // untuk jaga-jaga
  ],
  theme: {
    extend: {
      transitionProperty: {
        colors: "background-color, border-color, color, fill, stroke",
      },
    },
  },
  plugins: [],
};
