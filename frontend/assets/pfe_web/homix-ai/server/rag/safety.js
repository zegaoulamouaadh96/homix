export function isHarmful(text) {
  const t = (text || "").toLowerCase();
  const bad = [
    "hack","crack","bypass","exploit","malware","virus",
    "اختراق","تهكير","تجسس","فتح بدون إذن","اقتحام",
    "pirater","attaque","contourner","voler"
  ];
  return bad.some(w => t.includes(w));
}

export function containsSensitive(text) {
  const t = (text || "").toLowerCase();
  const bad = ["password","mot de passe","كلمة المرور","otp","2fa","token","jwt","api key","كود المنزل","secret"];
  return bad.some(w => t.includes(w));
}
