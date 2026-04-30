#include "core"
#include "math"
#include "bots"

// ============================
// INICIO
// ============================
stock iniciarBot() {
    seed(getID());
    walk();
}

// ============================
// ESCANEO
// ============================
stock escanear(&float:headAngle, &headDir) {

    new float:delta = 0.2618 * float(headDir);
    headAngle = headAngle + delta;

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

    new float:angle = dir + (randTurn * 1.2); // más fuerte

    rotate(angle);
}

// ============================
// RAMBO MOVIMIENTO
// ============================
stock moverseRambo() {

    new float:dir = getDirection();
    new float:randTurn = (float(random(200)) / 100.0) - 1.0;

    new float:angle = dir + (randTurn * 0.5);

    rotate(angle);
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

        new float:dir = getDirection();
        new float:torso = getTorsoYaw();
        new float:head = getHeadYaw();

        new float:angle = dir + torso + head + yaw;

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
// EVITAR PAREDES (MEJORADO)
// ============================
stock evitarParedes() {

    new float:distWall = sight();

    if (distWall < 7.0) {

        new float:dir = getDirection();

        // 🔥 GIRO FUERTE (tipo rebote)
        new float:angle = dir + 3.1415; // PI → girar 180°

        // pequeña variación para que no todos hagan lo mismo
        angle = angle + ((float(random(100)) / 100.0) - 0.5);

        rotate(angle);

        walk(); // 🔥 aseguramos movimiento

        wait(0.1);

        return 1;
    }

    return 0;
}

// ============================
// EVITAR COLISIONES (FIX REAL)
// ============================
stock evitarColisiones() {

    new touched = getTouched();

    if ((touched & ITEM_WARRIOR) != 0) {

        new float:dir = getDirection();
        new float:angle;

        if (random(2) == 0) {
            angle = dir + 2.0;
        } else {
            angle = dir - 2.0;
        }

        rotate(angle);

        // 🔥 CLAVE: FORZAR QUE SIGA CAMINANDO
        walk();

        wait(0.1);

        return 1;
    }

    return 0;
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

        // 🔥 PRIORIDAD 1: PAREDES
        if (evitarParedes()) {
            wait(0.04);
            continue;
        }

        // 🔥 PRIORIDAD 2: COLISIONES
        if (evitarColisiones()) {
            wait(0.04);
            continue;
        }

        // ============================
        // FASE 1: DISPERSIÓN
        // ============================
        if ((getTime() - startTime) < 4.0) {

            moverseDispersion();
        }
        else {

            // ============================
            // FASE 2: ROLES
            // ============================

            if (getID() == 2) {

                moverseRambo();
                atacar();

            } else {
                // quietos pero SIN bloquear lógica
                if (!isStanding()) {
                    stand();
                }
            }
        }

        // comportamiento común
        escanear(headAngle, headDir);

        if (!isWalking() && getID() == 2) {
            walk();
        }

        wait(0.04);
    }
}