# Stix Arcade Clone - Play Instructions

## Game Goal
Your objective is to claim territory by carving up the screen. You must capture **75% or more** of the empty black space to clear the stage and advance to the next level. 
Each new level increases the number of bouncing Stix enemies roaming the field.

---

## Controls Matrix

| Action | Control Key | Description |
| :---            | :---        | :---        |
| 🕹️ **Movement** | **Arrow Keys** | Controls your light-cyan player dot across the grid. |
| 🔄 **Toggle Mode** | **Spacebar** | Switches drawing speed modes (**only works while safe on blue walls**). |
| 🔁 **Restart Game** | **R Key** | Restarts the game from Stage 1 after a **Game Over**. |

---
<table border="1" cellpadding="8" style="border-collapse: collapse; width: 100%; text-align: left;">
  <thead>
    <tr style="background-color: #f2f2f2;">
      <th>Action</th>
      <th>Control Key</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>🕹️ <strong>Movement</strong></td>
      <td><strong>Arrow Keys</strong></td>
      <td>Controls your light-cyan player dot across the grid.</td>
    </tr>
    <tr>
      <td>🔄 <strong>Toggle Mode</strong></td>
      <td><strong>Spacebar</strong></td>
      <td>Switches drawing speed modes (<strong>only works while safe on blue walls</strong>).</td>
    </tr>
    <tr>
      <td>🔁 <strong>Restart Game</strong></td>
      <td><strong>R Key</strong></td>
      <td>Restarts the game from Stage 1 after a <strong>Game Over</strong>.</td>
    </tr>
  </tbody>
</table>

---

## Mechanics & Scoring System

* 🛡️ **The Safe Zone (Blue Walls):** You start on the blue outer border. As long as you stay on the blue lines, you are safe from enemies.
* 🟠 **Fast Draw Mode (Orange Trail):** Moving out into empty space draws an orange trail. This moves at standard speed and awards you standard points (**10 pts per cell**) when you complete the shape.
* 🟣 **Slow Draw Mode (Fuchsia Trail):** Pressing the Spacebar before leaving a wall changes your trail to purple. You move at **half speed**, making you highly vulnerable, but rewards you with **double points** (**20 pts per cell**).
* ⚡ **The Fuse Spark (Flickering Dot):** If you stop moving out in the open for **2 seconds**, a spark ignites at the tail end of your trail and begins crawling down your line. It will not stop until you connect to a blue wall. If it touches you, you lose a life.
* 👾 **The Stix Enemies (Neon Lines):** Avoid letting the bouncing lines touch your temporary orange or purple trail. If a Stix cuts your path before you finish drawing your shape, your trail breaks and you lose a life.
