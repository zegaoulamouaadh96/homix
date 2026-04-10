const chatBtn = document.getElementById("chatBtn");
const chatWidget = document.getElementById("chatWidget");
const chatClose = document.getElementById("chatClose");
const chatSend = document.getElementById("chatSend");
const chatInput = document.getElementById("chatInput");
const chatMessages = document.getElementById("chatMessages");

function getSessionId(){
  let id = localStorage.getItem("homix_session");
  if(!id){
    id = (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()));
    localStorage.setItem("homix_session", id);
  }
  return id;
}

function addMessage(text, who="bot"){
  const div = document.createElement("div");
  div.className = `msg ${who}`;
  div.innerHTML = text;
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

async function askAI(message){
  const res = await fetch("/api/chat",{
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({ sessionId: getSessionId(), message })
  });
  const data = await res.json();
  return data.reply || "حدث خطأ.";
}

async function send(){
  const msg = chatInput.value.trim();
  if(!msg) return;
  chatInput.value = "";
  addMessage(msg, "user");
  addMessage("… جاري التفكير", "bot");

  try{
    const reply = await askAI(msg);
    // remove last "thinking"
    chatMessages.lastChild.remove();
    addMessage(reply, "bot");
  }catch(e){
    chatMessages.lastChild.remove();
    addMessage("تعذر الاتصال بالسيرفر المحلي. تأكد أن API شغالة على نفس الدومين/المنفذ.", "bot");
  }
}

chatBtn.onclick = () => {
  chatWidget.classList.toggle("active");
  if(chatWidget.classList.contains("active")){
    if(chatMessages.childElementCount === 0){
      addMessage("أهلًا 👋 أنا HomiX AI. اسألني عن المزايا، التركيب، الدعم، أو اطلب Demo.", "bot");
    }
    setTimeout(()=> chatInput.focus(), 100);
  }
};
chatClose.onclick = () => chatWidget.classList.remove("active");
chatSend.onclick = send;

chatInput.addEventListener("keydown", (e)=>{
  if(e.key === "Enter"){
    e.preventDefault();
    send();
  }
});
