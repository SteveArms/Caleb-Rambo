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

// Esquiva proactivamente a compañeros cercanos usando watch().
// Detecta amigos (ITEM_WARRIOR|ITEM_FRIEND) a menos de 'umbral' unidades.
// Usa walkbk para retroceder y luego rodea al compañero con angulo diagonal.
// Retorna 1 si esquivo, 0 si no.
stock evitarCompanero(float:umbral = 5.0) {
    new item = ITEM_WARRIOR | ITEM_FRIEND
    new float:dist = 0.0
    new float:yaw
    watch(item, dist, yaw)

    // Solo esquivar si detectamos un compañero cerca
    if (item == ITEM_WARRIOR | ITEM_FRIEND && dist < umbral && dist > 0.0) {
        // Si el compañero esta al frente (yaw dentro de ~60°)
        new float:absYaw = yaw
        if (absYaw < 0.0) {
            absYaw = -absYaw
        }
        if (absYaw < 1.0472) {  // ~60 grados, compañero en el camino
            // Paso 1: Retroceder para crear espacio
            stand()
            wait(0.2)
            walkbk()
            wait(0.6)
            stand()
            wait(0.2)

            // Paso 2: Calcular angulo de escape diagonal (no 90° puro)
            // Usar el angulo al compañero para ir al lado opuesto + 45°
            new float:evadeAngle
            new float:companeroAngle = getDirection() + yaw  // angulo absoluto al compañero
            if (yaw >= 0.0) {
                // Compañero a la izquierda -> rodear por la derecha
                evadeAngle = companeroAngle - PI + 0.7854  // opuesto + 45° derecha
            } else {
                // Compañero a la derecha -> rodear por la izquierda
                evadeAngle = companeroAngle + PI - 0.7854  // opuesto + 45° izquierda
            }
            rotate(evadeAngle)
            wait(0.5)
            walk()
            wait(0.3)
            run()
            wait(1.0)  // correr un poco para despejar
            return 1
        }
    }
    return 0
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

        wait(0.04)
    }
}

// ═══════════════════════════════════════════════════════════════════
//  CALEB (ID 1) - Patrulla esquinas, detecta enemigos, reporta por radio
// ═══════════════════════════════════════════════════════════════════

loopCaleb() {
    new huyendo = 0
    new misionCompleta = 0   // 1 = ya entrego info, ya no patrulla
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

        // --- Mision completada: Caleb se queda parado inhabilitado ---
        if (misionCompleta == 1) {
            stand()
            rotateHead(0.0)   // cancelar rotacion de cabeza
            wait(1.0)
            // Inhabilitado: no hace nada mas
        } else {

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
                new float:absoluteAngle = getDirection() + getTorsoYaw() + getHeadYaw() + yaw
                localEnemyX = myX + dist * cos(absoluteAngle)
                localEnemyY = myY + dist * sin(absoluteAngle)
                printf("Caleb myX:%f myY:%f^n", myX, myY)
                printf("Caleb dist:%f yaw:%f^n", dist, yaw)
                printf("Caleb absoluteAngle:%f^n", absoluteAngle)
            }

            // --- Si detecto enemigo, reportar al lider ---
            if (huyendo == 1) {
                calebReportarAlLider(huyendo, misionCompleta, localEnemyX, localEnemyY)
            } else {
                // --- Navegar hacia la esquina actual ---
                calebPatrullarEsquinas(cornersX, cornersY, cornerIndex)
            }

            // --- Evitar paredes y colisiones (solo si no termino mision) ---
            if (misionCompleta == 0) {
                if (evitarPared()) {
                    if (huyendo == 1) { run(); } else { walk(); }
                }
                if (evitarColision()) {
                    if (huyendo == 1) { run(); } else { walk(); }
                }
                if (!huyendo && !isWalking()) {
                    walk()
                }
            }
        }

        wait(0.04)
    }
}

// Caleb reporta al lider por radio cuando esta a menos de 50 unidades.
// Si esta mas lejos, corre hacia el lider hasta entrar en rango.
// Una vez enviado el reporte, queda inhabilitado (misionCompleta = 1).
stock calebReportarAlLider(&huyendo, &misionCompleta, float:localEnemyX, float:localEnemyY) {
    new float:leaderX
    new float:leaderY
    new float:myX
    new float:myY

    getGoalLocation(0, leaderX, leaderY)
    getLocation(myX, myY)

    new float:distToLeader = calcDist(myX, myY, leaderX, leaderY)

    if (distToLeader < 50.0) {
        // Dentro de rango: enviar por radio inmediatamente
        stand()
        huyendo = 0

        printf("Caleb en rango (dist:%f), enviando por radio^n", distToLeader)
        printf("Caleb enviando msgX:%d msgY:%d^n",
               encodeCoord(localEnemyX), encodeCoord(localEnemyY))

        enviarCoordenadas(CHANNEL_CALEB, MSG_ENEMY_POS, localEnemyX, localEnemyY)

        // Mision cumplida: Caleb queda inhabilitado
        misionCompleta = 1
        printf("Caleb: reporte enviado, quedando inhabilitado^n")
        stand()

    } else {
        // Fuera de rango: correr hacia el lider hasta estar a <50
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

// Fase 1: Espera bloqueante hasta recibir coordenadas del Jefe.
// Retorna cuando tiene destX/destY listos.
stock ramboEsperarOrdenes() {
    printf("Rambo: esperando ordenes...^n")
    stand()

    new estado = 0
    for (;;) {
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
                printf("Rambo recibio destX:%f destY:%f^n", destX, destY)
                return   // ordenes recibidas, salir de la espera
            }
        }
        wait(0.04)
    }
}

// Navega corriendo desde la posicion actual hasta (tx, ty).
// Maneja paredes, colisiones con soldados, y esquiva compañeros proactivamente.
stock ramboNavHacia(float:tx, float:ty) {
    new float:myX
    new float:myY

    // Orden correcto: parar → rotar → correr
    if (!isStanding()) {
        stand()
        wait(1.0)
    }
    getLocation(myX, myY)
    rotate(calcAngleTo(myX, myY, tx, ty))
    wait(1.0)   // esperar a que complete la rotacion
    walk()      // walk() primero — no se puede ir de stand a run directamente
    wait(1.0)
    run()
    wait(0.5)   // esperar a que arranque

    for (;;) {
        getLocation(myX, myY)

        if (calcDist(myX, myY, tx, ty) < 3.0) {
            stand()
            wait(1.0)
            return
        }

        // Corregir rumbo si se desvio mucho
        rotate(calcAngleTo(myX, myY, tx, ty))

        // --- Anti-choque proactivo con compañeros ---
        // Detecta amigos cercanos ANTES de colisionar y los rodea
        if (evitarCompanero(5.0)) {
            // Despues de esquivar, recalcular rumbo al destino
            getLocation(myX, myY)
            rotate(calcAngleTo(myX, myY, tx, ty))
            wait(0.5)
            if (!isRunning()) {
                walk()
                wait(0.5)
                run()
                wait(0.5)
            }
        }

        // Evitar paredes: parar, girar 90°, continuar
        if (sight() < 3.0) {
            stand()
            wait(1.0)
            new float:evade
            if (random(2) == 0) {
                evade = getDirection() + HALF_PI
            } else {
                evade = getDirection() - HALF_PI
            }
            rotate(evade)
            wait(1.0)
            run()
            wait(0.5)
        }

        // Evitar colision fisica con cualquier soldado (respaldo)
        // Usa walkbk para retroceder y luego gira diagonal para salir
        if (getTouched() & ITEM_WARRIOR != 0) {
            // Retroceder para despegarse
            stand()
            wait(0.2)
            walkbk()
            wait(0.8)
            stand()
            wait(0.2)
            // Girar ~135° (opuesto + 45°) para rodear
            new float:evade2
            evade2 = getDirection() + PI - 0.7854
            rotate(evade2)
            wait(0.5)
            walk()
            wait(0.3)
            run()
            wait(0.5)
        }

        if (!isRunning()) {
            run()
            wait(0.5)
        }

        wait(0.04)
    }
}

// Fase 2: Se separa del grupo retrocediendo, luego corre al destino.
stock ramboIrAlDestino() {
    new float:myX
    new float:myY
    getLocation(myX, myY)

    // Calcular si los compañeros estan cerca al inicio
    new float:leaderX
    new float:leaderY
    getGoalLocation(0, leaderX, leaderY)
    new float:distToLeader = calcDist(myX, myY, leaderX, leaderY)

    // Si estamos cerca del grupo, primero retroceder para despegarnos
    if (distToLeader < 8.0) {
        printf("Rambo: separandose del grupo...^n")
        // Girar OPUESTO al lider para alejarse
        new float:awayAngle = calcAngleTo(leaderX, leaderY, myX, myY)
        rotate(awayAngle)
        wait(1.0)
        walk()
        wait(0.5)
        run()
        wait(2.0)  // correr 2 segundos para separarse bien
        stand()
        wait(0.5)
    }

    printf("Rambo: corriendo al objetivo^n")
    ramboNavHacia(destX, destY)

    printf("Rambo: llego al destino^n")
}


// Fase 3: Caza al enemigo en el area del destino. Gira, apunta y dispara.
stock ramboCazar() {
    printf("Rambo: modo caza activado^n")

    new headDir = 1
    new float:headAngle = 0.0
    new float:lastShot = 0.0

    for (;;) {
        // Rotar cabeza para escanear
        rotarCabeza(headAngle, headDir)

        // Detectar enemigo
        new item = ITEM_WARRIOR | ITEM_ENEMY
        new float:dist = 0.0
        new float:yaw
        watch(item, dist, yaw)

        if (item == ITEM_WARRIOR | ITEM_ENEMY) {
            // Apuntar el cuerpo al enemigo
            rotate(getDirection() + getTorsoYaw() + getHeadYaw() + yaw)
            wait(0.1)

            new aimItem
            aim(aimItem)
            if (aimItem & ITEM_ENEMY != 0) {
                if (getTime() - lastShot >= 0.4) {
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

        wait(0.04)
    }
}

// Loop principal de Rambo: fases secuenciales
loopRambo() {
    seed(0)
    stand()

    for (;;) {
        // Fase 1 — Esperar ordenes del Jefe
        ramboEsperarOrdenes()

        // Fase 2 — Ir corriendo al destino
        ramboIrAlDestino()

        // Fase 3 — Cazar en el area (loop infinito hasta nuevo mensaje)
        ramboCazar()
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