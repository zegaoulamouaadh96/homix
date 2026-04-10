Linux quick run (no Ctrl+C shutdown issues)

1) Update code
   cd /opt/PFE
   git pull origin main

2) Prepare env file once
   cp /opt/PFE/tools/linux/homix.env.example /opt/PFE/tools/linux/homix.env
   nano /opt/PFE/tools/linux/homix.env

   Important:
   - Set JWT_SECRET to a strong random value.
   - Keep FACE_PYTHON_URL as http://127.0.0.1:5000

3) Make scripts executable once
   chmod +x /opt/PFE/tools/linux/homix-start.sh
   chmod +x /opt/PFE/tools/linux/homix-stop.sh
   chmod +x /opt/PFE/tools/linux/homix-status.sh

4) Start services in background
   /opt/PFE/tools/linux/homix-start.sh

5) Check status
   /opt/PFE/tools/linux/homix-status.sh

6) Tail logs
   tail -f /opt/PFE/.logs/api.log
   tail -f /opt/PFE/.logs/ai.log

7) Stop services
   /opt/PFE/tools/linux/homix-stop.sh

Why your curl was failing:
- You ran node index.js in foreground then pressed Ctrl+C.
- Ctrl+C terminates the process, so port 3000 closes.
- After that, curl to 127.0.0.1:3000 returns connection refused.
