#include "core"
#include "math"
#include "bots"

#define CHANNEL 1
#define MSG_ENEMY 200

// ============================
// VARIABLES RAMBO
// ============================
new float:targetX = 0.0;
new float:targetY = 0.0;
new bool:tieneObjetivo = false;

// ============================
// INICIO
// ============================
stock iniciarBot() {
    seed(getID());
    walk();
}

// ============================
// ATAN2
// ============================
stock float:atan2(float:y, float:x) {

    if (abs(x) < 0.00001) {
        if (y > 0.0) return 1.5708;
        return -1.5708;
    }

    new float:a = atan(y / x);

    if (x < 0.0) {
        if (y >= 0.0) return a + 3.1415;
        return a - 3.1415;
    }

    return a;
}

// ============================
// ESCANEO
// ============================
stock escanear(&float:headAngle, &headDir) {

    headAngle += 0.2618 * float(headDir);

    if (headAngle >= 1.0472) {
        headAngle = 1.0472;
        headDir = -1;
    } 
    else if (headAngle <= -1.0472) {
        headAngle = -1.0472;
        headDir = 1;
    }

    rotateHead(headAngle);
}

// ============================
// DISPERSIÓN
// ============================
stock moverseDispersion() {
    new float:dir = getDirection();
    new float:randTurn = (float(random(200)) / 100.0) - 1.0;
    rotate(dir + randTurn * 1.2);
}

// ============================
// ATAQUE
// ============================
stock atacar() {

    new item;
    new float:dist = 0.0;
    new float:yaw = 0.0;

    watch(item, dist, yaw);

    if ((item & ITEM_ENEMY) != 0) {

        new float:angle = getDirection() + yaw;

        rotate(angle);
        wait(0.2);

        new aimItem;
        aim(aimItem);

        if ((aimItem & ITEM_ENEMY) != 0) {
            shootBullet();
        }
    }
}

// ============================
// EVITAR PAREDES
// ============================
stock evitarParedes() {

    if (sight() < 7.0) {

        new float:angle = getDirection() + 3.1415;
        angle += ((float(random(100)) / 100.0) - 0.5);

        rotate(angle);
        walk();

        wait(0.1);
        return 1;
    }
    return 0;
}

// ============================
// EVITAR COLISIONES
// ============================
stock evitarColisiones() {

    new touched = getTouched();

    if ((touched & ITEM_WARRIOR) != 0) {

        new float:angle;

        if (random(2) == 0) {
            angle = getDirection() + 2.0;
        } else {
            angle = getDirection() - 2.0;
        }

        rotate(angle);
        walk();

        wait(0.1);
        return 1;
    }
    return 0;
}

// ============================
// LÍDER (datos simulados)
// ============================
stock liderEnviar() {

    static estado = 0;
    static float:lastTime = 0.0;

    if (getTime() - lastTime < getTimeNeededFor(ACTION_SPEAK)) {
        return;
    }

    if (estado == 0) {
        if (speak(CHANNEL, MSG_ENEMY)) {
            estado = 1;
            lastTime = getTime();
        }
    }
    else if (estado == 1) {
        if (speak(CHANNEL, 50)) { // yaw
            estado = 2;
            lastTime = getTime();
        }
    }
    else if (estado == 2) {
        if (speak(CHANNEL, 60)) { // distancia
            estado = 0;
            lastTime = getTime();
        }
    }
}

// ============================
// RAMBO RECIBE
// ============================
stock ramboRecibir() {

    new msg, sender;

    static estado = 0;
    static float:yaw = 0.0;
    static float:dist = 0.0;

    if (listen(CHANNEL, msg, sender)) {

        if (estado == 0 && msg == MSG_ENEMY) {
            estado = 1;
        }
        else if (estado == 1) {
            yaw = float(msg) / 100.0;
            estado = 2;
        }
        else if (estado == 2) {

            dist = float(msg) / 100.0;
            estado = 0;

            new float:x, float:y, float:z;
            getLocation(x, y, z);

            new float:angle = getDirection() + getTorsoYaw() + getHeadYaw() + yaw;

            targetX = x + cos(angle) * dist;
            targetY = y + sin(angle) * dist;

            tieneObjetivo = true;
        }
    }
}

// ============================
// RAMBO MOVER (FIX REAL)
// ============================
stock ramboMover() {

    if (!tieneObjetivo) {
        return;
    }

    new float:x, float:y, float:z;
    getLocation(x, y, z);

    new float:dx = targetX - x;
    new float:dy = targetY - y;

    new float:dist = sqrt(dx*dx + dy*dy);

    // 🔥 LLEGÓ
    if (dist < 1.0) {

        tieneObjetivo = false;

        if (!isStanding()) {
            stand();
        }

        return;
    }

    new float:targetAngle = atan2(dy, dx);
    new float:current = getDirection();
    new float:diff = targetAngle - current;

    // NORMALIZAR
    if (diff > 3.1415) diff -= 6.2830;
    if (diff < -3.1415) diff += 6.2830;

    // 🔥 CLAVE: SOLO GIRAR SI ES NECESARIO
    if (abs(diff) > 0.1) {
        rotate(current + diff);
    }

    // 🔥 SOLO CAMINA SI YA ESTÁ MÁS O MENOS ALINEADO
    if (abs(diff) < 0.5) {
        if (!isWalking()) {
            walk();
        }
    } else {
        stand();
    }
}

// ============================
// MAIN
// ============================
main() {

    iniciarBot();

    new headDir = 1;
    new float:headAngle = 0.0;

    new float:startTime = getTime();

    while (true) {

        if (getID() == 0) {
            liderEnviar();
        }

        if (evitarParedes()) { wait(0.04); continue; }
        if (evitarColisiones()) { wait(0.04); continue; }

        if ((getTime() - startTime) < 4.0) {

            moverseDispersion();

            if (!isWalking()) {
                walk();
            }
        }
        else {

            if (getID() == 2) {

                ramboRecibir();
                ramboMover();
                atacar();
            }
            else {

                if (!isStanding()) {
                    stand();
                }
            }
        }

        escanear(headAngle, headDir);

        wait(0.04);
    }
}