#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
#define SCREEN_ADDRESS 0x3C ///< See datasheet for Address; 0x3D or 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

const int trigPin = 9;
const int echoPin = 10;

long duration;
int distanceCm;
int distanceInch;

void setup() {
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.begin(9600);

  // Initialize OLED display
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }
  
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
}

void loop() {
  // Clear the trigPin
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  
  // Set the trigPin HIGH for 10 microseconds
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  // Read the echoPin
  duration = pulseIn(echoPin, HIGH);
  
  // Calculate distance
  distanceCm = duration * 0.034 / 2;
  distanceInch = duration * 0.0133 / 2;
  
  // Update OLED Display
  display.clearDisplay();
  
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("Distance Meter");
  
  display.setTextSize(2);
  display.setCursor(0, 20);
  display.print(distanceCm);
  Serial.println(distanceCm);
  display.print(" cm");
  
  display.setCursor(0, 45);
  display.print(distanceInch);
  display.print(" in");
  
  display.display();
  
  delay(500);
}
