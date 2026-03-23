void setup() {
  pinMode(13, OUTPUT);
  Serial.begin(115200);
}

void loop() {
  digitalWrite(13, HIGH);
  Serial.println("RobotKit D13 HIGH");
  delay(250);
  digitalWrite(13, LOW);
  Serial.println("RobotKit D13 LOW");
  delay(250);
}
