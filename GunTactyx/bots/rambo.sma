/* script.sma - Bot ID 2 (Rambo) y Bot ID 1 (Caleb) */
#include "core"
#include "math"
#include "bots"

#define CHANNEL_ORDERS   0
#define CHANNEL_CALEB    1
#define ORDER_GO_LOCATION  1  // ir a ubicacion aleatoria
#define MSG_ENEMY_POS      2

new const float:PI       = 3.1416
new const float:HALF_PI  = 1.5708
new const float:HEAD_STEP   = 0.2618
new const float:HEAD_MAX    = 1.0472

new float:destX = 0.0
new float:destY = 0.0
new goingToDest = 0

// ═══════════════════════════════════════════════════════════════════
//  Funciones utilitarias
// ═══════════════════════════════════════════════════════════════════

// Calcula atan2(dy, dx) con manejo correcto de cuadrantes
stock float:myAtan2(float:dy, float:dx) {
    if (dx == 0.0) {
        if (dy > 0.0) {
            return HALF_PI
        } else {
            return -HALF_PI
        }
    }
    new float:a = atan(dy / dx)
    if (dx < 0.0 && dy >= 0.0) {
        a = a + PI
    } else if (dx < 0.0 && dy < 0.0) {
        a = a - PI
    }
    return a
}

// Calcula el angulo desde (fromX,fromY) hacia (toX,toY)
stock float:calcAngleTo(float:fromX, float:fromY, float:toX, float:toY) {
    return myAtan2(toY - fromY, toX - fromX)
}

// Distancia euclidiana entre dos puntos
stock float:calcDist(float:fromX, float:fromY, float:toX, float:toY) {
    new float:dx = toX - fromX
    new float:dy = toY - fromY
    return sqrt(dx*dx + dy*dy)
}

// Codifica un float como int para enviar por speak()
stock encodeCoord(float:val) {
    return floatround(val * 10.0) + 700
}

// Decodifica un int recibido por listen() a float
stock float:decodeCoord(val) {
    return float(val - 700) / 10.0
}

// ═══════════════════════════════════════════════════════════════════
//  Funciones compartidas de comportamiento
// ═══════════════════════════════════════════════════════════════════

// Rota la cabeza en ping-pong entre -HEAD_MAX y +HEAD_MAX
stock rotarCabeza(&float:headAngle, &headDir) {
    headAngle = headAngle + HEAD_STEP * float(headDir)
    if (headAngle >= HEAD_MAX) {
        headAngle = HEAD_MAX
        headDir = -1
    } else if (headAngle <= -HEAD_MAX) {
        headAngle = -HEAD_MAX
        headDir = 1
    }
    rotateHead(headAngle)
}

// Evita paredes girando 90 grados al azar. Retorna 1 si esquivo, 0 si no.
stock evitarPared() {
    if (sight() < 3.0) {
        stand()
        wait(1.0)
        new float:angle
        if (random(2) == 0) {
            angle = getDirection() + HALF_PI
        } else {
            angle = getDirection() - HALF_PI
        }
        rotate(angle)
        wait(1.0)
        return 1
    }
    return 0
}

// Evita colisiones con soldados girando 90 grados al azar. Retorna 1 si esquivo.
stock evitarColision() {
    new touched = getTouched()
    if (touched & ITEM_WARRIOR != 0) {
        stand()
        wait(1.0)
        new float:angle
        if (random(2) == 0) {
            angle = getDirection() + HALF_PI
        } else {
            angle = getDirection() - HALF_PI
        }
        rotate(angle)
        wait(1.0)
        return 1
    }
    return 0
}

// Evitar pared version Rambo (con cooldown, sin stop)
stock evitarParedConCooldown(&float:lastWall) {
    if (sight() < 3.0 && getTime() - lastWall >= 1.0) {
        new float:angle
        if (random(2) == 0) {
            angle = getDirection() + HALF_PI
        } else {
            angle = getDirection() - HALF_PI
        }
        rotate(angle)
        lastWall = getTime()
        if (goingToDest == 1) {
            walk()
        }
    }
}

// Evitar colision version Rambo (con cooldown, sin stop)
stock evitarColisionConCooldown(&float:lastCollision) {
    if (getTouched() & ITEM_WARRIOR != 0 && getTime() - lastCollision >= 1.0) {
        new float:angle
        if (random(2) == 0) {
            angle = getDirection() + HALF_PI
        } else {
            angle = getDirection() - HALF_PI
        }
        rotate(angle)
        lastCollision = getTime()
        if (goingToDest == 1) {
            walk()
        }
    }
}

// Envia 3 palabras por speak() con cooldown: header, coordX, coordY
// Retorna cuando termina el envio completo.
stock enviarCoordenadas(channel, header, float:coordX, float:coordY) {
    new estadoEnvio = 0
    new float:lastTimeSend = 0.0
    new msgX = encodeCoord(coordX)
    new msgY = encodeCoord(coordY)

    while (estadoEnvio < 3) {
        if (getTime() - lastTimeSend >= 0.25) {
            if (estadoEnvio == 0) {
                if (speak(channel, header)) {
                    lastTimeSend = getTime()
                    estadoEnvio = 1
                }
            }
            else if (estadoEnvio == 1) {
                if (speak(channel, msgX)) {
                    lastTimeSend = getTime()
                    estadoEnvio = 2
                }
            }
            else if (estadoEnvio == 2) {
                if (speak(channel, msgY)) {
                    lastTimeSend = getTime()
                    estadoEnvio = 3
                }
            }
        }
        wait(0.04)
    }
}

// ═══════════════════════════════════════════════════════════════════
//  JEFE (ID 0) - Retransmite posiciones de Caleb a Rambo
// ═══════════════════════════════════════════════════════════════════

loopJefe() {
    seed(0)

    new float:targetX = 0.0
    new float:targetY = 0.0

    new estadoEnvio = 0
    new float:lastTime = 0.0

    // Estado de recepcion de Caleb
    new estadoRecepcion = 0
    new tieneInfoEnemigo = 0

    for (;;) {

        // --- Escuchar a Caleb ---
        new word
        new id
        if (listen(CHANNEL_CALEB, word, id)) {

            if (estadoRecepcion == 0 && word == MSG_ENEMY_POS) {
                estadoRecepcion = 1
            }
            else if (estadoRecepcion == 1) {
                targetX = decodeCoord(word)
                estadoRecepcion = 2
            }
            else if (estadoRecepcion == 2) {
                targetY = decodeCoord(word)
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
                    new msgX = encodeCoord(targetX)
                    if (speak(CHANNEL_ORDERS, msgX)) {
                        lastTime = getTime()
                        estadoEnvio = 2
                    }
                }
                else if (estadoEnvio == 2) {
                    new msgY = encodeCoord(targetY)
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
}

// ═══════════════════════════════════════════════════════════════════
//  CALEB (ID 1) - Patrulla esquinas, detecta enemigos, huye al lider
// ═══════════════════════════════════════════════════════════════════

loopCaleb() {
    new huyendo = 0
    new headDir = 1
    new float:headAngle = 0.0
    new float:localEnemyX = 0.0
    new float:localEnemyY = 0.0

    // Coordenadas de las 4 esquinas
    new float:cornersX[4] = {65.0, -65.0, -65.0,  65.0}
    new float:cornersY[4] = {65.0,  65.0, -65.0, -65.0}
    new cornerIndex = 0

    stand()
    wait(1.0)
    walk()

    for (;;) {

        // --- Rotar cabeza para escanear ---
        rotarCabeza(headAngle, headDir)

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
            calebHuirAlLider(huyendo, localEnemyX, localEnemyY)
        } else {
            // --- Navegar hacia la esquina actual ---
            calebPatrullarEsquinas(cornersX, cornersY, cornerIndex)
        }

        // --- Evitar paredes y colisiones ---
        if (evitarPared()) {
            if (huyendo == 1) {
                run()
            } else {
                walk()
            }
        }

        if (evitarColision()) {
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
}

// Caleb huye hacia el lider. Cuando llega, envia coordenadas del enemigo.
stock calebHuirAlLider(&huyendo, float:localEnemyX, float:localEnemyY) {
    new float:leaderX
    new float:leaderY
    new float:myX
    new float:myY

    getGoalLocation(0, leaderX, leaderY)
    getLocation(myX, myY)

    new float:distToLeader = calcDist(myX, myY, leaderX, leaderY)

    if (distToLeader < 3.0) {
        huyendo = 0

        printf("Caleb enviando msgX:%d msgY:%d^n",
               encodeCoord(localEnemyX), encodeCoord(localEnemyY))

        enviarCoordenadas(CHANNEL_CALEB, MSG_ENEMY_POS, localEnemyX, localEnemyY)

        stand()
        wait(1.0)
        walk()

    } else {
        new float:angleToLeader = calcAngleTo(myX, myY, leaderX, leaderY)
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
}

// Caleb navega de esquina en esquina
stock calebPatrullarEsquinas(float:cornersX[], float:cornersY[], &cornerIndex) {
    new float:myX
    new float:myY
    getLocation(myX, myY)

    new float:distToCorner = calcDist(myX, myY, cornersX[cornerIndex], cornersY[cornerIndex])

    if (distToCorner < 3.0) {
        // Avanzar a la siguiente esquina
        cornerIndex = (cornerIndex + 1) % 4
    } else {
        new float:angleToCorner = calcAngleTo(myX, myY, cornersX[cornerIndex], cornersY[cornerIndex])
        rotate(angleToCorner)
        if (!isWalking()) {
            walk()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
//  RAMBO (ID 2) - Recibe coordenadas del jefe, navega y ataca
// ═══════════════════════════════════════════════════════════════════

loopRambo() {
    seed(0)

    new headDir = 1
    new float:headAngle = 0.0
    new estado = 0
    new float:lastShot = 0.0
    new float:lastRotate = 0.0
    new float:lastWall = 0.0
    new float:lastCollision = 0.0

    // Rambo espera parado hasta recibir orden del jefe
    stand()

    for (;;) {

        // --- Escuchar coordenadas del jefe ---
        ramboEscucharOrdenes(estado)

        // --- Navegar hacia el destino ---
        if (goingToDest == 1) {
            ramboNavegar()
        }

        // --- Rotar cabeza para escanear ---
        rotarCabeza(headAngle, headDir)

        // --- Detectar y atacar enemigos ---
        ramboAtacar(lastShot, lastRotate)

        // --- Evitar paredes y colisiones ---
        evitarParedConCooldown(lastWall)
        evitarColisionConCooldown(lastCollision)

        wait(0.04)
    }
}

// Rambo escucha ordenes del jefe (maquina de estados de 3 pasos)
stock ramboEscucharOrdenes(&estado) {
    new word
    new id
    if (listen(CHANNEL_ORDERS, word, id)) {

        if (estado == 0 && word == ORDER_GO_LOCATION) {
            estado = 1
        }
        else if (estado == 1) {
            destX = decodeCoord(word)
            estado = 2
        }
        else if (estado == 2) {
            destY = decodeCoord(word)
            estado = 0
            goingToDest = 1
            printf("Rambo recibio destX:%f destY:%f^n", destX, destY)
        }
    }
}

// Rambo navega hacia destX/destY
stock ramboNavegar() {
    new float:myX
    new float:myY
    getLocation(myX, myY)

    new float:distToDest = calcDist(myX, myY, destX, destY)

    if (distToDest < 2.0) {
        // Llego al destino, vuelve a esperar parado
        goingToDest = 0
        stand()
    } else {
        new float:angleToTarget = calcAngleTo(myX, myY, destX, destY)
        rotate(angleToTarget)
        if (!isWalking()) {
            stand()
            wait(1.0)
            walk()
        }
    }
}

// Rambo detecta y ataca enemigos
stock ramboAtacar(&float:lastShot, &float:lastRotate) {
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
}

// ═══════════════════════════════════════════════════════════════════
//  Punto de entrada
// ═══════════════════════════════════════════════════════════════════

main() {
    if (getID() == 0) {
        loopJefe()
    } else if (getID() == 1) {
        loopCaleb()
    } else if (getID() == 2) {
        loopRambo()
    } else {
        for (;;) {
            wait(1.0)
        }
    }
}