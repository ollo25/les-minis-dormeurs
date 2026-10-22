#include <Wire.h>

// ==================== CONFIGURATION ====================

#define BMI160_ADDR 0x69

#define PIEZO_PIN A0

int piezoRepos = 8;
int seuilPiezo = 20;

#define BUZZER_PIN 8
#define MOTOR_PIN 9

#define REG_CMD 0x7E

// true quand Godot a trouvé la carte
bool paired = false;


// ==================== LECTURE DU BMI160 ====================

bool lireBMI(int &ax, int &ay, int &az, int &gx, int &gy, int &gz) {

  // ----- Gyroscope -----

  Wire.beginTransmission(BMI160_ADDR);
  Wire.write(0x0C);
  Wire.endTransmission(false);

  Wire.requestFrom((uint8_t)BMI160_ADDR, (uint8_t)6);

  if (Wire.available() < 6) {
    return false;
  }

  gx = (int16_t)(Wire.read() | (Wire.read() << 8));
  gy = (int16_t)(Wire.read() | (Wire.read() << 8));
  gz = (int16_t)(Wire.read() | (Wire.read() << 8));


  // ----- Accelerometre -----

  Wire.beginTransmission(BMI160_ADDR);
  Wire.write(0x12);
  Wire.endTransmission(false);

  Wire.requestFrom((uint8_t)BMI160_ADDR, (uint8_t)6);

  if (Wire.available() < 6) {
    return false;
  }

  ax = (int16_t)(Wire.read() | (Wire.read() << 8));
  ay = (int16_t)(Wire.read() | (Wire.read() << 8));
  az = (int16_t)(Wire.read() | (Wire.read() << 8));

  return true;
}


// ==================== CALCUL DU NIVEAU ====================

// Seuils de sensibilite : plus les nombres sont grands, moins c'est sensible.
// (Historique : 40/100/250/500/1500 puis 60/150/375/750/2000, jugees trop sensibles.)
const long SEUIL_1 = 100;
const long SEUIL_2 = 250;
const long SEUIL_3 = 600;
const long SEUIL_4 = 1200;
const long SEUIL_5 = 3000;

int calculerNiveauMouvement(long intensiteGyro) {

  if (intensiteGyro <= SEUIL_1) {
    return 0;
  }

  if (intensiteGyro <= SEUIL_2) {
    return 1;
  }

  if (intensiteGyro <= SEUIL_3) {
    return 2;
  }

  if (intensiteGyro <= SEUIL_4) {
    return 3;
  }

  if (intensiteGyro <= SEUIL_5) {
    return 4;
  }

  return 5;
}


// ==================== SETUP ====================

void setup() {

  Wire.begin();

  Serial.begin(115200);

  Serial.setTimeout(20);   // ne pas rester bloque si une ligne arrive incomplete


  // ----- Attente de Godot (même principe que le sketch des profs) -----
  // Godot cherche la carte en envoyant "DISCOVER" sur les ports USB.
  // On répond "GDSERIAL_ACK" pour lui dire "c'est moi". Tant que Godot
  // n'a pas trouvé la carte, on reste bloqué ici.
  while (!paired) {
    if (Serial.available() > 0) {
      String cmd = Serial.readStringUntil('\n');
      cmd.trim();
      if (cmd == "DISCOVER") {
        Serial.println("GDSERIAL_ACK:bebe");
        paired = true;
      }
    }
  }

  delay(1000);


  // ----- Buzzer -----

  pinMode(BUZZER_PIN, OUTPUT);

  digitalWrite(BUZZER_PIN, HIGH);


  // ----- Moteur -----

  pinMode(MOTOR_PIN, OUTPUT);

  digitalWrite(MOTOR_PIN, LOW);


  Serial.println("Demarrage systeme poupee");
  Serial.println("------------------------");


  // ----- Verification BMI160 -----

  Wire.beginTransmission(BMI160_ADDR);

  Wire.write(0x00);

  Wire.endTransmission(false);

  Wire.requestFrom((uint8_t)BMI160_ADDR, (uint8_t)1);


  if (Wire.available()) {

    byte chipID = Wire.read();

    Serial.print("CHIP_ID = 0x");

    if (chipID < 16) {
      Serial.print("0");
    }

    Serial.println(chipID, HEX);


    if (chipID != 0xD1) {

      Serial.println("ERREUR : BMI160 non reconnu !");

    } else {

      Serial.println("BMI160 correctement detecte !");
    }

  } else {

    Serial.println("ERREUR : aucune reponse du BMI160 !");
  }


  // ----- Demarrage gyroscope -----

  Wire.beginTransmission(BMI160_ADDR);

  Wire.write(REG_CMD);

  Wire.write(0x15);

  Wire.endTransmission();

  delay(200);


  // ----- Demarrage accelerometre -----

  bool accelOK = false;


  for (int essai = 1; essai <= 5 && !accelOK; essai++) {

    Wire.beginTransmission(BMI160_ADDR);

    Wire.write(REG_CMD);

    Wire.write(0x11);

    Wire.endTransmission();

    delay(200);


    Wire.beginTransmission(BMI160_ADDR);

    Wire.write(0x03);

    Wire.endTransmission(false);

    Wire.requestFrom((uint8_t)BMI160_ADDR, (uint8_t)1);


    if (Wire.available()) {

      byte etat = Wire.read();

      if (etat & 0x08) {

        accelOK = true;
      }
    }
  }


  if (accelOK) {

    Serial.println("Accelerometre et gyroscope actives.");

  } else {

    Serial.println("ERREUR : l'accelerometre ne demarre pas !");
  }


  Serial.println("------------------------");

  Serial.println("SYSTEME PRET");
}


// ==================== LOOP ====================

// Le probleme d'avant : on ne mesurait qu'une fois toutes les 200 ms.
// Quand on secoue le bebe, le mouvement va et vient : si la mesure tombait
// pile dans un "creux" (le moment ou le bras change de sens), on lisait 1 ou 2.
//
// Maintenant : on mesure tres souvent (toutes les 10 ms), on GARDE LE PLUS FORT
// mouvement vu, et toutes les 100 ms on envoie a Godot le niveau de ce maximum.
// Comme ca, aucune secousse n'est ratee.

const unsigned long INTERVALLE_ENVOI = 100;   // ms entre deux envois a Godot

unsigned long dernierEnvoi = 0;
long intensiteMax = 0;    // plus fort mouvement depuis le dernier envoi
int piezoMax = 0;         // plus fort choc depuis le dernier envoi (pour le debug)

// true quand Godot demande de faire vibrer le bebe (commande "vibe:1", arret avec "vibe:0")
bool vibreurActif = false;


void loop() {

  // ----- Commandes envoyees par Godot -----
  // "vibe:1" = le bebe vibre, "vibe:0" = il arrete

  if (Serial.available() > 0) {

    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    if (cmd == "vibe:1") {
      vibreurActif = true;
      digitalWrite(MOTOR_PIN, HIGH);
    }

    if (cmd == "vibe:0") {
      vibreurActif = false;
      digitalWrite(MOTOR_PIN, LOW);
    }
  }


  // ----- Lecture du piezo -----

  int piezo = analogRead(PIEZO_PIN);

  if (piezo > piezoMax) {
    piezoMax = piezo;
  }


  // ----- Lecture BMI160 -----

  int ax;
  int ay;
  int az;

  int gx;
  int gy;
  int gz;

  bool bmiOK = lireBMI(ax, ay, az, gx, gy, gz);

  if (bmiOK) {

    // Intensite totale du gyroscope

    long intensiteGyro =
      (long)abs(gx) +
      (long)abs(gy) +
      (long)abs(gz);

    // On garde le plus fort mouvement

    if (intensiteGyro > intensiteMax) {
      intensiteMax = intensiteGyro;
    }
  }
  else {

    Serial.println("ERREUR lecture BMI160");
  }


  // ----- Envoi a Godot toutes les 100 ms -----

  if (millis() - dernierEnvoi >= INTERVALLE_ENVOI) {

    dernierEnvoi = millis();

    int niveauMouvement = calculerNiveauMouvement(intensiteMax);


    // ==================================================
    // DEBUG POUR NOUS
    // ==================================================

    Serial.print("PIEZO:");
    Serial.print(piezoMax);

    Serial.print(" GYRO_INT:");
    Serial.print(intensiteMax);

    Serial.print(" NIVEAU:");
    Serial.println(niveauMouvement);


    // ==================================================
    // DONNEE DESTINEE A GODOT
    // ==================================================

    Serial.print("NIVEAU:");
    Serial.println(niveauMouvement);


    // On repart de zero pour les 100 prochaines ms

    intensiteMax = 0;
    piezoMax = 0;
  }


  // ==================================================
  // PIEZO
  // ==================================================

  if (piezo > piezoRepos + seuilPiezo) {

    digitalWrite(BUZZER_PIN, LOW);

    digitalWrite(MOTOR_PIN, HIGH);

    delay(200);

    digitalWrite(BUZZER_PIN, HIGH);

    // On remet le moteur comme Godot l'a demande (allume s'il doit vibrer)
    if (vibreurActif) {
      digitalWrite(MOTOR_PIN, HIGH);
    } else {
      digitalWrite(MOTOR_PIN, LOW);
    }
  }


  delay(10);
}
