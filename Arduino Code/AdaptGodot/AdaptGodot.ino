// =============================================
//  Arduino — Auto-pairing avec GdSerial
// =============================================

const int LED1_PIN    = 13;
const int LED2_PIN    = 5;
const int LED3_PIN    = 6;
const int ENC_S1_PIN = 3;   // S1 de l'encodeur : doit être une broche à interruption (2 ou 3 sur l'Uno, la 2 est prise)
const int ENC_S2_PIN = 4;   // S2 de l'encodeur
const int ECHO_PIN = 11;
const int TRIG_PIN = 12;
const int BUTTON_PIN = 2;   // KEY de l'encodeur : LOW quand on appuie
const int VIB_PIN = 10;

bool paired = false;
unsigned long lastSendTime = 0;
const unsigned long SEND_INTERVAL = 50;
bool lastButtonState = false;
int nbLed = 0;

// ── Moyenne glissante ultrason ─────────────────
const int WINDOW_SIZE = 5;
float ultrasonBuffer[WINDOW_SIZE];
int ultrasonIndex = 0;
bool bufferFull = false;

float smoothedUltrason() {
  float rawDuration = 0;
  float rawDistance = 0;

  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(5);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  rawDuration = pulseIn(ECHO_PIN, HIGH);
  rawDistance = rawDuration * 0.034 / 2;

  // Stocke dans le buffer circulaire
  ultrasonBuffer[ultrasonIndex] = rawDistance;
  ultrasonIndex = (ultrasonIndex + 1) % WINDOW_SIZE;
  if (ultrasonIndex == 0) bufferFull = true;

  // Calcule la moyenne sur les valeurs disponibles
  int count = bufferFull ? WINDOW_SIZE : ultrasonIndex;
  float sum = 0;
  for (int i = 0; i < count; i++) sum += ultrasonBuffer[i];
  return sum / count;
}
// ──────────────────────────────────────────────

// ── Encodeur rotatif ───────────────────────────
// Il remplace le potentiomètre : on envoie toujours "potentiometre:0..1023".
// L'encodeur tourne sans fin, donc la valeur fait le tour comme un angle :
// après la plus grande valeur on repasse à 0, et sous 0 on repasse en haut.
const int TOUR_COMPLET = 1024;       // 0 à 1023 = un tour complet du personnage
const int CRANS_PAR_TOUR = 20;       // 20 crans = un tour de bouton = un tour du personnage ; 40 pour des pas deux fois plus fins
const int CHANGEMENTS_PAR_CRAN = 2;  // S1 change 2 fois par cran ; si la valeur ne bouge qu'un cran sur deux, mettre 1

volatile int changementsS1 = 0;      // compté par l'interruption, vidé par lirePosition()
int cranCourant = 0;                 // de 0 à CRANS_PAR_TOUR - 1 ; au démarrage, le personnage est à 0

// Appelée à chaque changement de S1, même pendant un delay() ou un pulseIn() :
// aucun cran n'est perdu. S2 dit dans quel sens on tourne.
void compterEncodeur() {
  if (digitalRead(ENC_S1_PIN) == digitalRead(ENC_S2_PIN)) {
    changementsS1++;
  } else {
    changementsS1--;
  }
}

int lirePosition() {
  // On coupe les interruptions le temps de lire le compteur, sinon il peut
  // changer au milieu de la lecture (un int fait 2 octets sur l'Uno)
  noInterrupts();
  int crans = changementsS1 / CHANGEMENTS_PAR_CRAN;
  changementsS1 -= crans * CHANGEMENTS_PAR_CRAN;  // garde le demi-cran entamé
  interrupts();

  // En C++, % garde le signe : -1 % 20 vaut -1, pas 19. On rajoute donc un
  // tour avant de refaire le modulo, pour rester entre 0 et CRANS_PAR_TOUR - 1
  cranCourant = ((cranCourant + crans) % CRANS_PAR_TOUR + CRANS_PAR_TOUR) % CRANS_PAR_TOUR;

  // long : avec 40 crans, 39 * 1024 dépasse ce qu'un int tient sur l'Uno (32767)
  return (long)cranCourant * TOUR_COMPLET / CRANS_PAR_TOUR;
}
// ──────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  pinMode(LED1_PIN, OUTPUT);
  pinMode(LED2_PIN, OUTPUT);
  pinMode(LED3_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(VIB_PIN, OUTPUT);

  pinMode(ENC_S1_PIN, INPUT_PULLUP);
  pinMode(ENC_S2_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ENC_S1_PIN), compterEncodeur, CHANGE);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  // Pré-remplit le buffer avec une première mesure
  // pour éviter des valeurs à 0 au démarrage
  for (int i = 0; i < WINDOW_SIZE; i++) {
    ultrasonBuffer[i] = 0;
  }

  while (!paired) {
    if (Serial.available() > 0) {
      String cmd = Serial.readStringUntil('\n');
      cmd.trim();
      if (cmd == "DISCOVER") {
        Serial.println("GDSERIAL_ACK:arduino_uno");
        paired = true;
      }
    }
  }
}

void loop() {
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    if (!paired) {
      if (cmd == "DISCOVER") {
        Serial.println("GDSERIAL_ACK:arduino_uno");
        paired = true;
      }
    } else {
      //Lit les commandes en provenance de GODOT
      parseCommand(cmd);
    }
  }
  //Si on est "connecté" à GODOT, on envoi des manière régulière les valeurs des capteurs
  if (paired) {
    unsigned long now = millis();
    if (now - lastSendTime >= SEND_INTERVAL) {
      lastSendTime = now;
      sendSensors();
    }
  }
}

void parseCommand(const String& cmd) {
  int sep = cmd.indexOf(':');
  if (sep == -1) return;

  String key   = cmd.substring(0, sep);
  String value = cmd.substring(sep + 1);

  if (key == "led") {
    nbLed++;
    //A chaque réception d'un message avec "led", une nouvelle led s'allume
    switch (nbLed){
      case 1:
        digitalWrite(LED1_PIN, value == "1" ? HIGH : LOW);
        Serial.println("ack:led1:" + value);
        break;
      case 2:
        digitalWrite(LED2_PIN, value == "1" ? HIGH : LOW);
        Serial.println("ack:led2:" + value);
        break;
      case 3:
        digitalWrite(LED3_PIN, value == "1" ? HIGH : LOW);
        Serial.println("ack:led3:" + value);
        delay(3000);
        digitalWrite(LED3_PIN, LOW);
        digitalWrite(LED2_PIN, LOW);
        digitalWrite(LED1_PIN, LOW);
        nbLed = 0;
        break;
    }
  }
  else if(key == "vibe"){
      // value est un texte : "0" n'est pas faux, il faut le comparer à "1"
      digitalWrite(VIB_PIN, value == "1" ? HIGH : LOW);
  }
  else if (key == "ping") {
    Serial.println("pong:" + value);
  }
  //Animation de clignotement des leds à la fin
  else if (key == "final") {
    for (int i = 0; i < 3; i++){
      digitalWrite(LED1_PIN, LOW);
      digitalWrite(LED2_PIN, LOW);
      digitalWrite(LED3_PIN, LOW);
    }
  }
}

void sendSensors() {
  float distance = smoothedUltrason();
  Serial.println("ultrason:" + String(distance, 1));
  Serial.println("potentiometre:" + String(lirePosition()));
  bool btn = (digitalRead(BUTTON_PIN) == LOW);
  if (btn != lastButtonState) {
    lastButtonState = btn;
    Serial.println("button:" + String(btn ? "1" : "0"));
  }
}
