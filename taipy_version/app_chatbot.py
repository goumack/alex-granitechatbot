from flask import Flask, render_template_string, request, jsonify
import logging
import requests
import time
from taipy_version.app_taipy import ALEXProClient
# Configuration des logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Nouveau template HTML minimal avec uniquement le widget chatbot
HTML_CHATBOT = """
<!DOCTYPE html>
<html lang=\"fr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>ALEX Chatbot</title>
    <link href=\"https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap\" rel=\"stylesheet\">
    <link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css\">
    <style>
        body { font-family: 'Inter', sans-serif; background: #f5f7fa; }
        .chat-toggle-btn { position: fixed; bottom: 80px; right: 20px; width: 60px; height: 60px; background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 50%, #1e40af 100%); border: none; border-radius: 50%; color: white; font-size: 24px; cursor: pointer; box-shadow: 0 4px 20px rgba(30, 58, 138, 0.3); z-index: 1000; display: flex; align-items: center; justify-content: center; }
        .chat-widget { position: fixed; bottom: 150px; right: 20px; width: 380px; height: 600px; background: white; border-radius: 20px; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15); z-index: 999; display: none; flex-direction: column; overflow: hidden; border: 1px solid rgba(30, 58, 138, 0.1); }
        .chat-widget.open { display: flex; }
        .chat-header { background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 50%, #1e40af 100%); color: white; padding: 20px; text-align: center; border-radius: 20px 20px 0 0; position: relative; }
        .close-chat-btn { position: absolute; top: 15px; right: 15px; background: none; border: none; color: white; font-size: 20px; cursor: pointer; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
        .chat-container { flex: 1; padding: 20px; overflow-y: auto; background: #f8f9fa; }
        .message { margin-bottom: 20px; padding: 18px 24px; border-radius: 18px; }
        .user-message { background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); color: white; margin-left: 20%; text-align: right; }
        .assistant-message { background: white; margin-right: 20%; color: #333; border: 1px solid #e9ecef; }
        .chat-input-section { padding: 20px; background: white; border-top: 1px solid #e9ecef; border-radius: 0 0 20px 20px; }
        .input-section { display: flex; gap: 10px; }
        #messageInput { flex: 1; padding: 12px 16px; border: 2px solid #e9ecef; border-radius: 25px; font-size: 14px; color: #333; outline: none; }
        .send-btn { background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 50%, #1e40af 100%); color: white; border: none; padding: 12px 20px; border-radius: 25px; cursor: pointer; font-size: 14px; font-weight: 500; min-width: 80px; }
        .loading { display: none; text-align: center; color: #2563eb; font-style: italic; font-weight: 500; margin: 15px 0; }
    </style>
</head>
<body>
    <button class=\"chat-toggle-btn\" id=\"chatToggle\" onclick=\"toggleChat()\">💬</button>
    <div class=\"chat-widget\" id=\"chatWidget\">
        <div class=\"container\">
            <div class=\"chat-header\">
                <button class=\"close-chat-btn\" onclick=\"toggleChat()\">×</button>
                <h1>ALEX by Accel Tech</h1>
                <p>Modernize. Innovate.</p>
            </div>
            <div class=\"chat-container\" id=\"chatContainer\">
                <div class=\"message assistant-message\">Bonjour ! Je suis ALEX, l'assistant IA d'Accel Tech. Comment puis-je vous aider ?</div>
            </div>
            <div class=\"loading\" id=\"loading\">ALEX réfléchit...</div>
            <div class=\"chat-input-section\">
                <div class=\"input-section\">
                    <input type=\"text\" id=\"messageInput\" placeholder=\"Posez votre question à ALEX...\" onkeypress=\"checkEnter(event)\">
                    <button class=\"send-btn\" id=\"sendBtn\" onclick=\"sendMessage()\">Envoyer</button>
                </div>
            </div>
        </div>
    </div>
    <script>
        function toggleChat() {
            const widget = document.getElementById('chatWidget');
            const toggleBtn = document.getElementById('chatToggle');
            if (widget.classList.contains('open')) {
                widget.classList.remove('open');
                toggleBtn.innerHTML = '💬';
                toggleBtn.classList.remove('active');
            } else {
                widget.classList.add('open');
                toggleBtn.innerHTML = '✕';
                toggleBtn.classList.add('active');
                setTimeout(() => { document.getElementById('messageInput').focus(); }, 300);
            }
        }
        function checkEnter(event) { if (event.key === 'Enter') { sendMessage(); } }
        async function sendMessage() {
            const input = document.getElementById('messageInput');
            const message = input.value.trim();
            if (!message) return;
            const chatContainer = document.getElementById('chatContainer');
            const sendBtn = document.getElementById('sendBtn');
            const loading = document.getElementById('loading');
            const userMessage = document.createElement('div');
            userMessage.className = 'message user-message';
            userMessage.textContent = message;
            chatContainer.appendChild(userMessage);
            input.value = '';
            sendBtn.disabled = true;
            loading.style.display = 'block';
            chatContainer.scrollTop = chatContainer.scrollHeight;
            try {
                const response = await fetch('/chat', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message: message })
                });
                const data = await response.json();
                const assistantMessage = document.createElement('div');
                assistantMessage.className = 'message assistant-message';
                assistantMessage.textContent = data.response;
                chatContainer.appendChild(assistantMessage);
            } catch (error) {
                const errorMessage = document.createElement('div');
                errorMessage.className = 'message assistant-message';
                errorMessage.textContent = 'Désolé, une erreur s\'est produite.';
                errorMessage.style.color = '#e74c3c';
                chatContainer.appendChild(errorMessage);
            }
            sendBtn.disabled = false;
            loading.style.display = 'none';
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }
    </script>
</body>
</html>
"""

app = Flask(__name__)
alex_client = ALEXProClient()

@app.route('/')
def home():
    return render_template_string(HTML_CHATBOT)

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.get_json()
        message = data.get('message', '')
        if not message:
            return jsonify({'response': 'Veuillez saisir un message.'}), 400
        response = alex_client.chat(message)
        return jsonify({'response': response})
    except Exception as e:
        logger.error(f"Erreur chat endpoint: {e}")
        return jsonify({'response': 'Une erreur s\'est produite.'}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8505, debug=False)
