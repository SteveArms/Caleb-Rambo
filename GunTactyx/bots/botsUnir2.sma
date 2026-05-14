
#include "core"
#include "math"
#include "bots"

/* ─── CONSTANTES GLOBALES ─────────────────────────────────────── */

new const float:PI       = 3.14159265
new const float:TWO_PI   = 6.28318530
new const float:HALF_PI  = 1.57079632

new const CHANNEL_CALEB      = 1
new const CHANNEL_JEFE_CALEB = 3
new const CHANNEL_HEARTBEAT  = 5    /* Rambo envia señal de vida aqui */
new const CHANNEL_RAMBO_BASE = 10   /* canal de cada Rambo = BASE + su ID */

new const MSG_ENEMY_POS  = 300
new const ORDER_GO       = 400
new const ORDER_SEARCH   = 500
new const MSG_ALIVE      = 600  /* heartbeat de Rambo */

new const float:HB_INTERVAL = 5.0   /* Rambo envia heartbeat cada 5 seg */
new const float:HB_TIMEOUT  = 15.0  /* Jefe espera max 15 seg sin señal */

/* destino de Rambo, global para que sea visible en todos los stocks */
new float:destX = 0.0
new float:destY = 0.0
new ramboChannel = 0   /* canal propio de cada Rambo, se asigna en loopRambo */
new float:lastHBTime = 0.0  /* ultimo heartbeat enviado por este Rambo */

/* ─── GRAFO DFS  (grilla 3x3, nodos 0-8) ─────────────────────── */
/*
 *  6--7--8
 *  |  |  |
 *  3--4--5
 *  |  |  |
 *  0--1--2
 */
new const DFS_N = 9

new float:nodeX[9]
new float:nodeY[9]

/* lista de adyacencia: 4 slots por nodo, -1 = vacio */
new adjList[36]

new dfsStack[9]
new dfsTop    = 0
new dfsVisited[9]

/* ─── MATH UTILS ──────────────────────────────────────────────── */

stock float:wrapPi(float:a) {
    while (a >  PI)
        a -= TWO_PI
    while (a < -PI)
        a += TWO_PI
    return a
}

stock float:calcDist(float:ax, float:ay, float:bx, float:by) {
    new float:dx
    new float:dy
    dx = bx - ax
    dy = by - ay
    return sqrt(dx*dx + dy*dy)
}

stock float:calcAngleTo(float:ax, float:ay, float:bx, float:by) {
    new float:dx
    new float:dy
    new float:a
    dx = bx - ax
    dy = by - ay
    if (dx > -0.0001 && dx < 0.0001) {
        if (dy >= 0.0)
            return HALF_PI
        else
            return -HALF_PI
    }
    a = atan(dy / dx)
    if (dx < 0.0) {
        if (dy >= 0.0)
            return a + PI
        else
            return a - PI
    }
    return a
}

stock encodeCoord(float:v) {
    return floatround(v * 100.0)
}

stock float:decodeCoord(encoded) {
    return float(encoded) / 100.0
}

/* ─── MOVIMIENTO COMPARTIDO ───────────────────────────────────── */

stock rotarCabeza(&float:headAngle, &headDir) {
    new float:step
    new float:maxYaw
    step   = 0.3
    maxYaw = 1.0
    headAngle = headAngle + step * float(headDir)
    if (headAngle >= maxYaw) {
        headAngle = maxYaw
        headDir   = -1
    } else if (headAngle <= -maxYaw) {
        headAngle = -maxYaw
        headDir   = 1
    }
    rotateHead(headAngle)
    wait(0.1)
}

stock evitarPared() {
    new float:angle
    if (sight() < 3.0) {
        stand()
        wait(1.0)
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

stock evitarColision() {
    new float:angle
    if (getTouched() & ITEM_WARRIOR != 0) {
        stand()
        wait(1.0)
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

stock enviarCoordenadas(channel, header, float:coordX, float:coordY) {
    new estado
    new float:lastTime
    new msgX
    new msgY
    estado   = 0
    lastTime = 0.0
    msgX     = encodeCoord(coordX)
    msgY     = encodeCoord(coordY)
    while (estado < 3) {
        if (getTime() - lastTime >= 0.3) {
            if (estado == 0) {
                if (speak(channel, header)) {
                    lastTime = getTime()
                    estado   = 1
                }
            } else if (estado == 1) {
                if (speak(channel, msgX)) {
                    lastTime = getTime()
                    estado   = 2
                }
            } else if (estado == 2) {
                if (speak(channel, msgY)) {
                    lastTime = getTime()
                    estado   = 3
                }
            }
        }
        wait(0.04)
    }
}

/* ─── DFS INIT ────────────────────────────────────────────────── */

stock initGrafo() {
    nodeX[0] = -45.0; nodeY[0] = -45.0
    nodeX[1] =   0.0; nodeY[1] = -45.0
    nodeX[2] =  45.0; nodeY[2] = -45.0
    nodeX[3] = -45.0; nodeY[3] =   0.0
    nodeX[4] =   0.0; nodeY[4] =   0.0
    nodeX[5] =  45.0; nodeY[5] =   0.0
    nodeX[6] = -45.0; nodeY[6] =  45.0
    nodeX[7] =   0.0; nodeY[7] =  45.0
    nodeX[8] =  45.0; nodeY[8] =  45.0

    adjList[0]  =  1; adjList[1]  =  3; adjList[2]  = -1; adjList[3]  = -1
    adjList[4]  =  0; adjList[5]  =  2; adjList[6]  =  4; adjList[7]  = -1
    adjList[8]  =  1; adjList[9]  =  5; adjList[10] = -1; adjList[11] = -1
    adjList[12] =  0; adjList[13] =  4; adjList[14] =  6; adjList[15] = -1
    adjList[16] =  1; adjList[17] =  3; adjList[18] =  5; adjList[19] =  7
    adjList[20] =  2; adjList[21] =  4; adjList[22] =  8; adjList[23] = -1
    adjList[24] =  3; adjList[25] =  7; adjList[26] = -1; adjList[27] = -1
    adjList[28] =  6; adjList[29] =  4; adjList[30] =  8; adjList[31] = -1
    adjList[32] =  7; adjList[33] =  5; adjList[34] = -1; adjList[35] = -1
}

stock dfsInit(float:spawnX, float:spawnY) {
    new i
    new startNode
    new float:bestDist
    new float:d
    for (i = 0; i < DFS_N; i++) {
        dfsVisited[i] = 0
    }
    dfsTop    = 0
    startNode = 0
    bestDist  = 9999.0
    for (i = 0; i < DFS_N; i++) {
        d = calcDist(spawnX, spawnY, nodeX[i], nodeY[i])
        if (d < bestDist) {
            bestDist  = d
            startNode = i
        }
    }
    dfsStack[dfsTop] = startNode
    dfsTop++
}

stock dfsNext() {
    new node
    new i
    new neighbor
    while (dfsTop > 0) {
        dfsTop--
        node = dfsStack[dfsTop]
        if (dfsVisited[node] == 0) {
            dfsVisited[node] = 1
            for (i = 3; i >= 0; i--) {
                neighbor = adjList[node * 4 + i]
                if (neighbor != -1 && dfsVisited[neighbor] == 0) {
                    if (dfsTop < DFS_N) {
                        dfsStack[dfsTop] = neighbor
                        dfsTop++
                    }
                }
            }
            return node
        }
    }
    return -1
}

/* ─── CALEB (ID 1) ────────────────────────────────────────────── */

stock calebEsperarOrden() {
    new word
    new id
    printf("Caleb: esperando orden del Jefe para buscar...^n")
    stand()
    for (;;) {
        if (listen(CHANNEL_JEFE_CALEB, word, id)) {
            if (word == ORDER_SEARCH) {
                printf("Caleb: orden recibida, iniciando busqueda^n")
                return
            }
        }
        wait(0.04)
    }
}

loopCaleb() {
    new float:spawnX
    new float:spawnY
    new float:spawnZ
    new float:enemX
    new float:enemY
    new currentNode
    new llegado
    new headDir
    new float:headAngle
    new item
    new float:dist
    new float:yaw
    new float:myX
    new float:myY
    new float:absAngle
    new float:angle
    new tieneEnemigo        /* 1 = detecto enemigo durante el DFS, pendiente de reportar */
    new dfsTerminado        /* 1 = DFS completo, regresando al spawn */
    new float:distSpawn

    seed(1)
    initGrafo()
    getLocation(spawnX, spawnY, spawnZ)

    calebEsperarOrden()

    enemX         = 0.0
    enemY         = 0.0
    currentNode   = -1
    llegado       = 1
    headDir       = 1
    headAngle     = 0.0
    tieneEnemigo  = 0
    dfsTerminado  = 0

    dfsInit(spawnX, spawnY)

    stand()
    wait(1.0)
    walk()

    for (;;) {
        /* ── Verificar vida de Caleb: terminar si murio ── */
        if (getHealth() <= 0) {
            printf("Caleb: vida agotada, terminando mision^n")
            return
        }

        rotarCabeza(headAngle, headDir)

        getLocation(myX, myY)

        /* ── FASE REGRESO: DFS terminado, volver al spawn y reportar ── */
        if (dfsTerminado == 1) {
            distSpawn = calcDist(myX, myY, spawnX, spawnY)

            /* Si tiene info de enemigo y ya esta cerca del spawn, reportar */
            if (tieneEnemigo == 1 && distSpawn <= 15.0) {
                printf("Caleb: cerca de base, enviando posicion enemigo X:%f Y:%f^n", enemX, enemY)
                enviarCoordenadas(CHANNEL_CALEB, MSG_ENEMY_POS, enemX, enemY)
                printf("Caleb: reporte enviado al Jefe^n")
                tieneEnemigo = 0
            }

            /* Si llego al spawn, reiniciar DFS para el siguiente ciclo */
            if (distSpawn < 4.0) {
                printf("Caleb: de regreso en base, reiniciando recorrido^n")
                dfsTerminado = 0
                dfsInit(spawnX, spawnY)
                llegado = 1
            } else {
                /* Navegar de regreso al spawn */
                angle = calcAngleTo(myX, myY, spawnX, spawnY)
                rotate(angle)
                if (!isWalking()) {
                    if (isStanding()) {
                        walk()
                        wait(1.0)
                    }
                }
                evitarPared()
                evitarColision()
                if (!isWalking()) {
                    walk()
                }
                wait(0.04)
                continue
            }
        }

        /* ── FASE DFS: explorar todos los nodos ── */
        item = ITEM_WARRIOR | ITEM_ENEMY
        dist = 0.0
        watch(item, dist, yaw)

        /* Enemigo detectado: guardar posicion, NO reportar aun */
        if ((item & ITEM_ENEMY) != 0 && (item & ITEM_WARRIOR) != 0 && dist > 0.0 && dist < 60.0) {
            absAngle = getDirection() + getTorsoYaw() + getHeadYaw() + yaw
            enemX    = myX + dist * cos(absAngle)
            enemY    = myY + dist * sin(absAngle)
            printf("Caleb: enemigo detectado en %f %f (guardado, pendiente de reporte)^n", enemX, enemY)
            tieneEnemigo = 1
        }

        /* Avanzar en el recorrido DFS */
        if (llegado == 1) {
            currentNode = dfsNext()
            if (currentNode == -1) {
                /* DFS completo: iniciar regreso al spawn */
                printf("Caleb: DFS completo, regresando a la base^n")
                dfsTerminado = 1
                stand()
                wait(0.5)
                walk()
                wait(0.04)
                continue
            }
            llegado = 0
            printf("Caleb: nodo %d (%f,%f)^n",
                   currentNode, nodeX[currentNode], nodeY[currentNode])
        }

        if (calcDist(myX, myY, nodeX[currentNode], nodeY[currentNode]) < 4.0) {
            llegado = 1
        } else {
            angle = calcAngleTo(myX, myY,
                                nodeX[currentNode], nodeY[currentNode])
            rotate(angle)
            if (!isWalking()) {
                if (isStanding()) {
                    walk()
                    wait(1.0)
                }
            }
        }

        evitarPared()
        evitarColision()

        if (!isWalking()) {
            walk()
        }

        wait(0.04)
    }
}

/* ─── JEFE (ID 0) ─────────────────────────────────────────────── */

stock jefeOrdenarBusqueda() {
    printf("Jefe: enviando orden de busqueda a Caleb...^n")
    while (!speak(CHANNEL_JEFE_CALEB, ORDER_SEARCH)) {
        wait(0.3)
    }
    printf("Jefe: orden de busqueda enviada^n")
}

loopJefe() {
    new float:targetX
    new float:targetY
    new estadoRx
    new estadoTx
    new float:lastTx
    new tieneInfo
    new word
    new id
    new esperandoRambo      /* 1 = hay un Rambo en mision, chequeamos HB */
    new float:lastTargetX
    new float:lastTargetY
    new nextRamboID
    new totalBots
    new txChannel
    new float:lastHBReceived  /* ultimo timestamp de MSG_ALIVE recibido */

    seed(0)
    targetX        = 0.0
    targetY        = 0.0
    estadoRx       = 0
    estadoTx       = 0
    lastTx         = 0.0
    tieneInfo      = 0
    esperandoRambo = 0
    lastTargetX    = 0.0
    lastTargetY    = 0.0
    nextRamboID    = 2
    totalBots      = getMates()
    txChannel      = CHANNEL_RAMBO_BASE + nextRamboID
    lastHBReceived = 0.0

    printf("Jefe: equipo de %d bots (%d Rambos disponibles)^n",
           totalBots, totalBots - 2)

    wait(1.0)
    jefeOrdenarBusqueda()

    for (;;) {

        /* ── Recibir posicion de enemigo desde Caleb ── */
        if (listen(CHANNEL_CALEB, word, id)) {
            if (estadoRx == 0 && word == MSG_ENEMY_POS) {
                estadoRx = 1
            } else if (estadoRx == 1) {
                targetX  = decodeCoord(word)
                estadoRx = 2
            } else if (estadoRx == 2) {
                targetY  = decodeCoord(word)
                estadoRx = 0
                tieneInfo = 1
                printf("Jefe: recibio X:%f Y:%f^n", targetX, targetY)
            }
        }

        /* ── Escuchar heartbeat de cualquier Rambo ── */
        if (listen(CHANNEL_HEARTBEAT, word, id)) {
            if (word == MSG_ALIVE) {
                lastHBReceived = getTime()
                printf("Jefe: heartbeat de Rambo (t=%f)^n", lastHBReceived)
            }
        }

        /* ── Enviar coordenadas al Rambo activo ── */
        if (tieneInfo == 1 && estadoRx == 0) {
            if (getTime() - lastTx >= 0.3) {
                if (estadoTx == 0) {
                    if (speak(txChannel, ORDER_GO)) {
                        lastTx   = getTime()
                        estadoTx = 1
                    }
                } else if (estadoTx == 1) {
                    if (speak(txChannel, encodeCoord(targetX))) {
                        lastTx   = getTime()
                        estadoTx = 2
                    }
                } else if (estadoTx == 2) {
                    if (speak(txChannel, encodeCoord(targetY))) {
                        lastTx   = getTime()
                        estadoTx = 0
                        tieneInfo      = 0
                        esperandoRambo = 1   /* hay Rambo en mision, activar chequeo de HB */
                        lastHBReceived = getTime()  /* darle margen para arrancar */
                        lastTargetX    = targetX
                        lastTargetY    = targetY
                        printf("Jefe: envio Rambo ID %d a X:%f Y:%f^n",
                               nextRamboID, targetX, targetY)
                    }
                }
            }
        }
        if (esperandoRambo == 1 && tieneInfo == 0) {
            if (getTime() - lastHBReceived >= HB_TIMEOUT) {
                /* Rambo activo murio o perdio comunicacion */
                nextRamboID++
                if (nextRamboID >= totalBots) {
                    nextRamboID = 2
                }
                txChannel = CHANNEL_RAMBO_BASE + nextRamboID
                printf("Jefe: sin HB por %f s, rotando a Rambo ID %d, reenvio a X:%f Y:%f^n",
                       HB_TIMEOUT, nextRamboID, lastTargetX, lastTargetY)

                /* Reencolar la misión para el nuevo Rambo */
                targetX   = lastTargetX
                targetY   = lastTargetY
                tieneInfo = 1
                estadoTx  = 0

                /* Resetear timer para darle margen al nuevo Rambo.
                 * esperandoRambo se mantiene en 1: el bloque de envio
                 * lo confirmara con lastHBReceived = getTime() al terminar. */
                lastHBReceived = getTime()
            }
        }

        wait(0.04)
    }
}

/* ─── RAMBO (ID >= 2) ─────────────────────────────────────────── */

stock ramboEsperarOrdenes() {
    new estado
    new word
    new id
    estado = 0
    printf("Rambo %d: esperando ordenes en canal %d...^n", getID(), ramboChannel)
    stand()
    for (;;) {
        /* Heartbeat mientras espera: el Jefe sabe que este Rambo esta vivo */
        if (getTime() - lastHBTime >= HB_INTERVAL) {
            speak(CHANNEL_HEARTBEAT, MSG_ALIVE)
            lastHBTime = getTime()
        }

        if (listen(ramboChannel, word, id)) {
            if (estado == 0 && word == ORDER_GO) {
                estado = 1
            } else if (estado == 1) {
                destX  = decodeCoord(word)
                estado = 2
            } else if (estado == 2) {
                destY  = decodeCoord(word)
                printf("Rambo %d: destino X:%f Y:%f^n", getID(), destX, destY)
                return
            }
        }
        wait(0.04)
    }
}

stock ramboNavHacia(float:tx, float:ty) {
    new float:myX
    new float:myY
    new float:targetAngle
    new float:diff
    new float:evade
    new float:prevX
    new float:prevY
    new stuckCount
    new tickCount

    if (!isStanding()) {
        stand()
        wait(1.0)
    }
    getLocation(myX, myY)
    rotate(calcAngleTo(myX, myY, tx, ty))
    wait(1.2)
    walk()
    wait(1.0)
    run()
    wait(0.5)

    prevX      = myX
    prevY      = myY
    stuckCount = 0
    tickCount  = 0

    for (;;) {
        getLocation(myX, myY)

        /* Heartbeat durante navegacion */
        if (getTime() - lastHBTime >= HB_INTERVAL) {
            speak(CHANNEL_HEARTBEAT, MSG_ALIVE)
            lastHBTime = getTime()
        }

        if (calcDist(myX, myY, tx, ty) < 5.0) {
            stand()
            wait(1.0)
            return
        }

        tickCount++
        if (tickCount >= 50) {
            tickCount = 0
            if (calcDist(myX, myY, prevX, prevY) < 1.5) {
                stuckCount++
                stand()
                wait(0.5)
                walkbk()
                wait(1.0)
                stand()
                wait(0.5)
                if (random(2) == 0) {
                    evade = getDirection() + HALF_PI
                } else {
                    evade = getDirection() - HALF_PI
                }
                rotate(evade)
                wait(1.2)
                walk()
                wait(0.5)
                run()
                wait(0.5)
            } else {
                stuckCount = 0
            }
            prevX = myX
            prevY = myY
        }

        targetAngle = calcAngleTo(myX, myY, tx, ty)
        diff        = wrapPi(targetAngle - getDirection())
        if (diff > 0.8 || diff < -0.8) {
            stand()
            wait(0.5)
            rotate(targetAngle)
            wait(1.2)
            run()
            wait(0.3)
        }

        if (sight() < 2.5) {
            stand()
            wait(0.5)
            if (random(2) == 0) {
                evade = getDirection() + HALF_PI
            } else {
                evade = getDirection() - HALF_PI
            }
            rotate(evade)
            wait(1.2)
            run()
            wait(0.5)
        }

        if (getTouched() & ITEM_WARRIOR != 0) {
            stand()
            wait(0.3)
            walkbk()
            wait(0.8)
            stand()
            wait(0.3)
            if (random(2) == 0) {
                evade = getDirection() + HALF_PI
            } else {
                evade = getDirection() - HALF_PI
            }
            rotate(evade)
            wait(0.8)
            walk()
            wait(0.5)
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

stock ramboCazar() {
    new headDir
    new float:headAngle
    new float:lastShot
    new rxEstado
    new word
    new id
    new item
    new float:dist
    new float:yaw
    new aimItem
    new float:aimAngle

    headDir   = 1
    headAngle = 0.0
    lastShot  = 0.0
    rxEstado  = 0

    printf("Rambo %d: modo caza^n", getID())

    for (;;) {
        /* Heartbeat durante la caza */
        if (getTime() - lastHBTime >= HB_INTERVAL) {
            speak(CHANNEL_HEARTBEAT, MSG_ALIVE)
            lastHBTime = getTime()
        }

        /* Escuchar nueva orden del Jefe */
        if (listen(ramboChannel, word, id)) {
            if (rxEstado == 0 && word == ORDER_GO) {
                rxEstado = 1
            } else if (rxEstado == 1) {
                destX    = decodeCoord(word)
                rxEstado = 2
            } else if (rxEstado == 2) {
                destY    = decodeCoord(word)
                rxEstado = 0
                printf("Rambo %d: nueva orden %f %f^n", getID(), destX, destY)
                return
            }
        }

        rotarCabeza(headAngle, headDir)

        item = ITEM_WARRIOR | ITEM_ENEMY
        dist = 0.0
        watch(item, dist, yaw)

        if ((item & ITEM_ENEMY) != 0 && (item & ITEM_WARRIOR) != 0) {
            aimAngle = getDirection() + getTorsoYaw() + getHeadYaw() + yaw
            rotate(aimAngle)
            wait(0.1)
            aim(aimItem)
            if (aimItem & ITEM_ENEMY != 0) {
                if (getTime() - lastShot >= 0.5) {
                    if (dist < 6.0 && getGrenadeLoad() > 0) {
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

loopRambo() {
    new myID
    myID         = getID()
    seed(myID)
    ramboChannel = CHANNEL_RAMBO_BASE + myID
    lastHBTime   = 0.0   /* forzar primer heartbeat inmediato */
    printf("Rambo %d: iniciado, canal %d^n", myID, ramboChannel)
    stand()
    for (;;) {
        ramboEsperarOrdenes()
        printf("Rambo %d: yendo a %f %f^n", myID, destX, destY)
        ramboNavHacia(destX, destY)
        ramboCazar()
    }
}

/* ─── MAIN ────────────────────────────────────────────────────── */

main() {
    new myID
    myID = getID()
    if (myID == 0) {
        loopJefe()
    } else if (myID == 1) {
        loopCaleb()
    } else {
        loopRambo()
    }
}
