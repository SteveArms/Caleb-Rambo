/* GUN-TACTYX - Equipo unificado
 * ID 0 = Jefe    : retransmite info de Caleb a Rambo
 * ID 1 = Caleb   : explora con DFS, reporta enemigos al Jefe
 * ID 2 = Rambo   : recibe coordenadas y va a cazar
 */
#include "core"
#include "math"
#include "bots"

/* ─── CONSTANTES GLOBALES ─────────────────────────────────────── */

new const float:PI       = 3.14159265
new const float:TWO_PI   = 6.28318530
new const float:HALF_PI  = 1.57079632

new const CHANNEL_CALEB  = 1
new const CHANNEL_ORDERS = 2

new const MSG_ENEMY_POS  = 300
new const ORDER_GO       = 400

/* destino de Rambo, global para que sea visible en todos los stocks */
new float:destX = 0.0
new float:destY = 0.0

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
    /* posiciones de los 9 nodos */
    nodeX[0] = -45.0; nodeY[0] = -45.0
    nodeX[1] =   0.0; nodeY[1] = -45.0
    nodeX[2] =  45.0; nodeY[2] = -45.0
    nodeX[3] = -45.0; nodeY[3] =   0.0
    nodeX[4] =   0.0; nodeY[4] =   0.0
    nodeX[5] =  45.0; nodeY[5] =   0.0
    nodeX[6] = -45.0; nodeY[6] =  45.0
    nodeX[7] =   0.0; nodeY[7] =  45.0
    nodeX[8] =  45.0; nodeY[8] =  45.0

    /* adyacencia: nodo 0 */
    adjList[0]  =  1; adjList[1]  =  3; adjList[2]  = -1; adjList[3]  = -1
    /* nodo 1 */
    adjList[4]  =  0; adjList[5]  =  2; adjList[6]  =  4; adjList[7]  = -1
    /* nodo 2 */
    adjList[8]  =  1; adjList[9]  =  5; adjList[10] = -1; adjList[11] = -1
    /* nodo 3 */
    adjList[12] =  0; adjList[13] =  4; adjList[14] =  6; adjList[15] = -1
    /* nodo 4 */
    adjList[16] =  1; adjList[17] =  3; adjList[18] =  5; adjList[19] =  7
    /* nodo 5 */
    adjList[20] =  2; adjList[21] =  4; adjList[22] =  8; adjList[23] = -1
    /* nodo 6 */
    adjList[24] =  3; adjList[25] =  7; adjList[26] = -1; adjList[27] = -1
    /* nodo 7 */
    adjList[28] =  6; adjList[29] =  4; adjList[30] =  8; adjList[31] = -1
    /* nodo 8 */
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

loopCaleb() {
    new float:spawnX
    new float:spawnY
    new float:spawnZ
    new huyendo
    new reportado
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
    new float:leaderX
    new float:leaderY
    new float:absAngle
    new float:angle

    seed(1)
    initGrafo()
    getLocation(spawnX, spawnY, spawnZ)

    huyendo     = 0
    reportado   = 0
    enemX       = 0.0
    enemY       = 0.0
    currentNode = -1
    llegado     = 1
    headDir     = 1
    headAngle   = 0.0

    dfsInit(spawnX, spawnY)

    stand()
    wait(1.0)
    walk()

    for (;;) {
        if (reportado == 1) {
            stand()
            wait(1.0)
        } else if (huyendo == 1) {
            getLocation(myX, myY)
            getGoalLocation(0, leaderX, leaderY)
            if (calcDist(myX, myY, leaderX, leaderY) < 50.0) {
                stand()
                wait(0.5)
                printf("Caleb: enviando X:%f Y:%f^n", enemX, enemY)
                enviarCoordenadas(CHANNEL_CALEB, MSG_ENEMY_POS, enemX, enemY)
                reportado = 1
                printf("Caleb: reporte listo, inhabilitado^n")
            } else {
                angle = calcAngleTo(myX, myY, leaderX, leaderY)
                rotate(angle)
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
                evitarPared()
                evitarColision()
            }
        } else {
            rotarCabeza(headAngle, headDir)

            item = ITEM_WARRIOR | ITEM_ENEMY
            dist = 0.0
            watch(item, dist, yaw)

            if ((item & ITEM_ENEMY) != 0 && (item & ITEM_WARRIOR) != 0 && dist > 0.0 && dist < 60.0) {
                getLocation(myX, myY)
                absAngle = getDirection() + getTorsoYaw() + getHeadYaw() + yaw
                enemX    = myX + dist * cos(absAngle)
                enemY    = myY + dist * sin(absAngle)
                printf("Caleb: enemigo en %f %f^n", enemX, enemY)
                huyendo = 1
                stand()
                wait(0.5)
                run()
            } else {
                if (llegado == 1) {
                    currentNode = dfsNext()
                    if (currentNode == -1) {
                        dfsInit(spawnX, spawnY)
                        currentNode = dfsNext()
                    }
                    llegado = 0
                    printf("Caleb: nodo %d (%f,%f)^n",
                           currentNode, nodeX[currentNode], nodeY[currentNode])
                }

                /* navegar al nodo actual */
                getLocation(myX, myY)
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

                if (!isWalking() && huyendo == 0) {
                    walk()
                }
            }
        }
        wait(0.04)
    }
}

/* ─── JEFE (ID 0) ─────────────────────────────────────────────── */

loopJefe() {
    new float:targetX
    new float:targetY
    new estadoRx
    new estadoTx
    new float:lastTx
    new tieneInfo
    new word
    new id

    seed(0)
    targetX  = 0.0
    targetY  = 0.0
    estadoRx = 0
    estadoTx = 0
    lastTx   = 0.0
    tieneInfo = 0

    for (;;) {
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

        if (tieneInfo == 1 && estadoRx == 0) {
            if (getTime() - lastTx >= 0.3) {
                if (estadoTx == 0) {
                    if (speak(CHANNEL_ORDERS, ORDER_GO)) {
                        lastTx   = getTime()
                        estadoTx = 1
                    }
                } else if (estadoTx == 1) {
                    if (speak(CHANNEL_ORDERS, encodeCoord(targetX))) {
                        lastTx   = getTime()
                        estadoTx = 2
                    }
                } else if (estadoTx == 2) {
                    if (speak(CHANNEL_ORDERS, encodeCoord(targetY))) {
                        lastTx    = getTime()
                        estadoTx  = 0
                        tieneInfo = 0
                        printf("Jefe: envio a Rambo X:%f Y:%f^n", targetX, targetY)
                    }
                }
            }
        }
        wait(0.04)
    }
}

/* ─── RAMBO (ID 2) ────────────────────────────────────────────── */

stock ramboEsperarOrdenes() {
    new estado
    new word
    new id
    estado = 0
    printf("Rambo: esperando ordenes...^n")
    stand()
    for (;;) {
        if (listen(CHANNEL_ORDERS, word, id)) {
            if (estado == 0 && word == ORDER_GO) {
                estado = 1
            } else if (estado == 1) {
                destX  = decodeCoord(word)
                estado = 2
            } else if (estado == 2) {
                destY  = decodeCoord(word)
                printf("Rambo: destino X:%f Y:%f^n", destX, destY)
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

        if (calcDist(myX, myY, tx, ty) < 5.0) {
            stand()
            wait(1.0)
            return
        }

        /* chequear stuck cada 50 ticks (~2 seg) */
        tickCount++
        if (tickCount >= 50) {
            tickCount = 0
            if (calcDist(myX, myY, prevX, prevY) < 1.5) {
                stuckCount++
                /* stuck: retroceder y girar */
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

        /* corregir rumbo solo si desviacion grande - NO interrumpe movimiento */
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

        /* pared cerca */
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

    printf("Rambo: modo caza^n")

    for (;;) {
        if (listen(CHANNEL_ORDERS, word, id)) {
            if (rxEstado == 0 && word == ORDER_GO) {
                rxEstado = 1
            } else if (rxEstado == 1) {
                destX    = decodeCoord(word)
                rxEstado = 2
            } else if (rxEstado == 2) {
                destY    = decodeCoord(word)
                rxEstado = 0
                printf("Rambo: nueva orden %f %f^n", destX, destY)
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
    seed(2)
    stand()
    for (;;) {
        ramboEsperarOrdenes()
        printf("Rambo: yendo a %f %f^n", destX, destY)
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
    } else if (myID == 2) {
        loopRambo()
    } else {
        for (;;)
            wait(1.0)
    }
}
