/* script.sma - Bot ID 2 recibe ordenes del jefe y ataca enemigos */
#include "core"
#include "math"
#include "bots"

#define CHANNEL_ORDERS  0
#define ORDER_GO_CENTER 1

main() {
    if (getID() == 0) {
        // --- JEFE (ID 0): envia orden de ir al centro ---
        while (true) {
            speak(CHANNEL_ORDERS, ORDER_GO_CENTER)
            wait(0.5)
        }

    } else if (getID() == 2) {
        // --- SOLDADO (ID 2) ---
        seed(0)

        new headDir = 1
        new float:headAngle = 0.0
        new goingToCenter = 0
        new float:centerX = 0.0
        new float:centerY = 0.0

        stand()
        wait(1.0)
        walk()

        while (true) {

            // --- Escuchar ordenes del jefe ---
            new word
            new id
            if (listen(CHANNEL_ORDERS, word, id)) {
                if (word == ORDER_GO_CENTER) {
                    goingToCenter = 1
                }
            }

            // --- Si recibio orden, orientarse hacia el centro ---
            if (goingToCenter == 1) {
                new float:myX
                new float:myY
                getLocation(myX, myY)

                new float:dx = centerX - myX
                new float:dy = centerY - myY

                // Calcular angulo hacia el centro con correccion de cuadrantes
                new float:angleToCenter
                if (dx == 0.0) {
                    if (dy > 0.0) {
                        angleToCenter = 1.5708   //  PI/2
                    } else {
                        angleToCenter = -1.5708  // -PI/2
                    }
                } else {
                    angleToCenter = atan(dy / dx)
                    if (dx < 0.0 && dy >= 0.0) {
                        angleToCenter = angleToCenter + 3.1416  // cuadrante 2
                    } else if (dx < 0.0 && dy < 0.0) {
                        angleToCenter = angleToCenter - 3.1416  // cuadrante 3
                    }
                    // cuadrantes 1 y 4: atan ya da el valor correcto
                }

                // Verificar si ya llego al centro
                new float:distToCenter = sqrt(dx*dx + dy*dy)
                if (distToCenter < 2.0) {
                    goingToCenter = 0
                } else {
                    rotate(angleToCenter)
                    if (!isWalking()) {
                        walk()
                    }
                }
            } else {
                if (!isWalking()) {
                    walk()
                }
            }

            // --- Rotar cabeza para escanear ---
            headAngle = headAngle + 0.2618 * float(headDir)
            if (headAngle >= 1.0472) {
                headAngle = 1.0472
                headDir = -1
            } else if (headAngle <= -1.0472) {
                headAngle = -1.0472
                headDir = 1
            }
            rotateHead(headAngle)

            // --- Detectar y atacar enemigos ---
            new item = ITEM_WARRIOR | ITEM_ENEMY
            new float:dist = 0.0
            new float:yaw
            watch(item, dist, yaw)

            if (item == ITEM_WARRIOR | ITEM_ENEMY) {
                rotate(getDirection() + getTorsoYaw() + getHeadYaw() + yaw)
                wait(0.5)

                new aimItem
                aim(aimItem)
                if (aimItem & ITEM_ENEMY != 0) {
                    if (dist < 5.0 && getGrenadeLoad() > 0) {
                        launchGrenade()
                        wait(0.5)
                    } else if (getBulletLoad() > 0) {
                        shootBullet()
                        wait(0.5)
                    }
                }
            }

            // --- Evitar paredes ---
            if (sight() < 3.0) {
                stand()
                wait(1.0)
                new randDir = random(2)
                new float:angle
                if (randDir == 0) {
                    angle = getDirection() + 1.5708
                } else {
                    angle = getDirection() - 1.5708
                }
                rotate(angle)
                wait(1.0)
                walk()
            }

            // --- Evitar colisiones con soldados ---
            new touched = getTouched()
            if (touched & ITEM_WARRIOR != 0) {
                stand()
                wait(1.0)
                new randDir2 = random(2)
                new float:angle2
                if (randDir2 == 0) {
                    angle2 = getDirection() + 1.5708
                } else {
                    angle2 = getDirection() - 1.5708
                }
                rotate(angle2)
                wait(1.0)
                walk()
            }

            wait(0.04)
        }

    } else {
        // --- Resto de bots ---
        while (true) {
            wait(1.0)
        }
    }
}