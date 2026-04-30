/* script.sma - Bot ID 2 (Rambo) y Bot ID 1 (Caleb) */
#include "core"
#include "math"
#include "bots"

#define CHANNEL_ORDERS   0
#define CHANNEL_CALEB    1
#define ORDER_GO_LOCATION  1  // ir a ubicacion aleatoria
#define MSG_ENEMY_POS      2

new float:destX = 0.0
new float:destY = 0.0
new goingToDest = 0

main() {
    if (getID() == 0) {
        // --- JEFE (ID 0) ---
        seed(0)

        new float:targetX = 0.0
        new float:targetY = 0.0

        new estadoEnvio = 0
        new float:lastTime = 0.0

        // Estado de recepcion de Caleb
        new estadoRecepcion = 0
        new tieneInfoEnemigo = 0

        while (true) {

            // --- Escuchar a Caleb ---
            new word
            new id
            if (listen(CHANNEL_CALEB, word, id)) {

                if (estadoRecepcion == 0 && word == MSG_ENEMY_POS) {
                    estadoRecepcion = 1
                }
                else if (estadoRecepcion == 1) {
                    targetX = float(word - 700) / 10.0
                    estadoRecepcion = 2
                }
                else if (estadoRecepcion == 2) {
                    targetY = float(word - 700) / 10.0
                    estadoRecepcion = 0
                    tieneInfoEnemigo = 1
                    printf("Jefe recibio targetX:%f targetY:%f^n", targetX, targetY)
                }
            }

            // --- Enviar coordenadas a Rambo ---
            // SOLO enviar si tiene info del enemigo
            if (estadoRecepcion == 0 && tieneInfoEnemigo == 1) {
            
                if (getTime() - lastTime >= 0.25) {
                
                    if (estadoEnvio == 0) {
                        if (speak(CHANNEL_ORDERS, ORDER_GO_LOCATION)) {
                            lastTime = getTime()
                            estadoEnvio = 1
                        }
                    }
                    else if (estadoEnvio == 1) {
                        new msgX = floatround(targetX * 10.0) + 700
                        if (speak(CHANNEL_ORDERS, msgX)) {
                            lastTime = getTime()
                            estadoEnvio = 2
                        }
                    }
                    else if (estadoEnvio == 2) {
                        new msgY = floatround(targetY * 10.0) + 700
                        if (speak(CHANNEL_ORDERS, msgY)) {
                            lastTime = getTime()
                            estadoEnvio = 0
                            tieneInfoEnemigo = 0
                            printf("Jefe envio a Rambo X:%f Y:%f^n", targetX, targetY)
                        }
                    }
                }
            }
        }

    } else if (getID() == 1) {
        // --- CALEB (ID 1) ---
        new huyendo = 0
        new headDir = 1
        new float:headAngle = 0.0
        new float:localEnemyX = 0.0  // agregar
        new float:localEnemyY = 0.0  // agregar

        // Coordenadas de las 4 esquinas
        new float:cornersX[4] = {65.0, -65.0, -65.0,  65.0}
        new float:cornersY[4] = {65.0,  65.0, -65.0, -65.0}
        new cornerIndex = 0

        stand()
        wait(1.0)
        walk()

        while (true) {

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

            // --- Detectar enemigos cercanos ---
            new item = ITEM_WARRIOR | ITEM_ENEMY
            new float:dist = 0.0
            new float:yaw
            watch(item, dist, yaw)

            if (item == ITEM_WARRIOR | ITEM_ENEMY && dist < 10.0 && huyendo == 0) {
                huyendo = 1
                new float:myX
                new float:myY
                getLocation(myX, myY)
                new float:absoluteAngle = getDirection() + getHeadYaw() + yaw
                localEnemyX = myX + dist * cos(absoluteAngle)
                localEnemyY = myY + dist * sin(absoluteAngle)
                printf("Caleb myX:%f myY:%f^n", myX, myY)
                printf("Caleb dist:%f yaw:%f^n", dist, yaw)
                printf("Caleb absoluteAngle:%f^n", absoluteAngle)
            }

            // --- Si hay enemigo cerca, correr hacia el lider ---
            if (huyendo == 1) {

                new float:leaderX
                new float:leaderY
                new float:myX
                new float:myY

                getGoalLocation(0, leaderX, leaderY)
                getLocation(myX, myY)

                new float:dx = leaderX - myX
                new float:dy = leaderY - myY

                new float:angleToLeader
                if (dx == 0.0) {
                    if (dy > 0.0) {
                        angleToLeader = 1.5708
                    } else {
                        angleToLeader = -1.5708
                    }
                } else {
                    angleToLeader = atan(dy / dx)
                    if (dx < 0.0 && dy >= 0.0) {
                        angleToLeader = angleToLeader + 3.1416
                    } else if (dx < 0.0 && dy < 0.0) {
                        angleToLeader = angleToLeader - 3.1416
                    }
                }

                new float:distToLeader = sqrt(dx*dx + dy*dy)
                if (distToLeader < 3.0) {
                    huyendo = 0

                    new estadoEnvio = 0
                    new float:lastTimeSend = 0.0
                    new msgX = floatround(localEnemyX * 10.0) + 700
                    new msgY = floatround(localEnemyY * 10.0) + 700

                    printf("Caleb enviando msgX:%d msgY:%d^n", msgX, msgY)

                    while (estadoEnvio < 3) {
                        if (getTime() - lastTimeSend >= 0.25) {
                            if (estadoEnvio == 0) {
                                if (speak(CHANNEL_CALEB, MSG_ENEMY_POS)) {
                                    lastTimeSend = getTime()
                                    estadoEnvio = 1
                                }
                            }
                            else if (estadoEnvio == 1) {
                                new msgX = floatround(localEnemyX * 10.0) + 700
                                if (speak(CHANNEL_CALEB, msgX)) {
                                    lastTimeSend = getTime()
                                    estadoEnvio = 2
                                }
                            }
                            else if (estadoEnvio == 2) {
                                new msgY = floatround(localEnemyY * 10.0) + 700
                                if (speak(CHANNEL_CALEB, msgY)) {
                                    lastTimeSend = getTime()
                                    estadoEnvio = 3
                                }
                            }
                        }
                        wait(0.04)
                    }

                    stand()
                    wait(1.0)
                    walk()

                } else {
                    rotate(angleToLeader)
                    if (!isRunning()) {
                        if (isWalking()) {
                            run()
                        } else {
                            stand()
                            wait(1.0)
                            walk()
                            wait(1.0)
                            run()
                        }
                    }
                }

            } else {
                // --- Navegar hacia la esquina actual ---
                new float:myX
                new float:myY
                getLocation(myX, myY)

                new float:dx = cornersX[cornerIndex] - myX
                new float:dy = cornersY[cornerIndex] - myY

                new float:angleToCorner
                if (dx == 0.0) {
                    if (dy > 0.0) {
                        angleToCorner = 1.5708
                    } else {
                        angleToCorner = -1.5708
                    }
                } else {
                    angleToCorner = atan(dy / dx)
                    if (dx < 0.0 && dy >= 0.0) {
                        angleToCorner = angleToCorner + 3.1416
                    } else if (dx < 0.0 && dy < 0.0) {
                        angleToCorner = angleToCorner - 3.1416
                    }
                }

                // Verificar si llego a la esquina actual
                new float:distToCorner = sqrt(dx*dx + dy*dy)
                if (distToCorner < 3.0) {
                    // Avanzar a la siguiente esquina
                    cornerIndex = (cornerIndex + 1) % 4
                } else {
                    rotate(angleToCorner)
                    if (!isWalking()) {
                        walk()
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
                if (huyendo == 1) {
                    run()
                } else {
                    walk()
                }
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
                if (huyendo == 1) {
                    run()
                } else {
                    walk()
                }
            }

            if (!huyendo && !isWalking()) {
                walk()
            }

            wait(0.04)
        }

    } else if (getID() == 2) {
        // --- RAMBO (ID 2) ---
        seed(0)

        new headDir = 1
        new float:headAngle = 0.0
        new estado = 0
        // Variables adicionales para Rambo
        new float:lastShot = 0.0
        new float:lastRotate = 0.0
        // Variables adicionales
        new float:lastWall = 0.0
        new float:lastCollision = 0.0

        // Rambo espera parado hasta recibir orden del jefe
        stand()

        while (true) {

            // --- Escuchar coordenadas del jefe ---
            new word
            new id
            if (listen(CHANNEL_ORDERS, word, id)) {

                if (estado == 0 && word == ORDER_GO_LOCATION) {
                    estado = 1
                }
                else if (estado == 1) {
                    destX = float(word - 700) / 10.0
                    estado = 2
                }
                else if (estado == 2) {
                    destY = float(word - 700) / 10.0
                    estado = 0
                    goingToDest = 1
                    printf("Rambo recibio destX:%f destY:%f^n", destX, destY)
                }
            }

            // --- Navegar hacia el destino ---
            if (goingToDest == 1) {

                new float:myX
                new float:myY
                getLocation(myX, myY)

                new float:dx = destX - myX
                new float:dy = destY - myY

                new float:angleToTarget
                if (dx == 0.0) {
                    if (dy > 0.0) {
                        angleToTarget = 1.5708
                    } else {
                        angleToTarget = -1.5708
                    }
                } else {
                    angleToTarget = atan(dy / dx)
                    if (dx < 0.0 && dy >= 0.0) {
                        angleToTarget = angleToTarget + 3.1416
                    } else if (dx < 0.0 && dy < 0.0) {
                        angleToTarget = angleToTarget - 3.1416
                    }
                }

                new float:distToDest = sqrt(dx*dx + dy*dy)
                if (distToDest < 2.0) {
                    // Llego al destino, vuelve a esperar parado
                    goingToDest = 0
                    stand()
                } else {
                    rotate(angleToTarget)
                    if (!isWalking()) {
                        stand()
                        wait(1.0)
                        walk()
                    }
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

            printf("dist:%f yaw:%f^n", dist, yaw)

            if (item == ITEM_WARRIOR | ITEM_ENEMY) {
                // Rotar solo si paso suficiente tiempo
                if (goingToDest == 0) {
                    // Solo rota el cuerpo si NO está navegando
                    if (getTime() - lastRotate >= 0.5) {
                        rotate(getDirection() + getTorsoYaw() + getHeadYaw() + yaw)
                        lastRotate = getTime()
                    }
                } else {
                    // Si está navegando, solo apunta el torso hacia el enemigo
                    rotateTorso(yaw)
                }

                new aimItem
                aim(aimItem)
                if (aimItem & ITEM_ENEMY != 0) {
                    // Disparar solo si paso suficiente tiempo desde el ultimo disparo
                    if (getTime() - lastShot >= 0.5) {
                        if (dist < 5.0 && getGrenadeLoad() > 0) {
                            launchGrenade()
                            lastShot = getTime()
                        } else if (getBulletLoad() > 0) {
                            shootBullet()
                            lastShot = getTime()
                        }
                    }
                }
            }

            // --- Evitar paredes ---
            if (sight() < 3.0 && getTime() - lastWall >= 1.0) {
                new randDir = random(2)
                new float:angle
                if (randDir == 0) {
                    angle = getDirection() + 1.5708
                } else {
                    angle = getDirection() - 1.5708
                }
                rotate(angle)
                lastWall = getTime()
                if (goingToDest == 1) {
                    walk()
                }
            }

            // --- Evitar colisiones con soldados ---
            if (getTouched() & ITEM_WARRIOR != 0 && getTime() - lastCollision >= 1.0) {
                new randDir2 = random(2)
                new float:angle2
                if (randDir2 == 0) {
                    angle2 = getDirection() + 1.5708
                } else {
                    angle2 = getDirection() - 1.5708
                }
                rotate(angle2)
                lastCollision = getTime()
                if (goingToDest == 1) {
                    walk()
                }
            }

            wait(0.04)
        }

    } else {
        while (true) {
            wait(1.0)
        }
    }
}