#include "core"
#include "math"
#include "bots"

// ============================
// INICIALIZACIÓN
// ============================
stock iniciarBot() {
    seed(0);
    stand();
    wait(1.0);
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
        wait(0.5);

        new aimItem;
        aim(aimItem);

        if ((aimItem & ITEM_ENEMY) != 0) {
            shootBullet();
            wait(0.5);
        }
    }
}

// ============================
// EVITAR PAREDES
// ============================
stock evitarParedes() {

    new float:distWall = sight();

    if (distWall < 3.0) {

        stand();
        wait(1.0);

        new randDir = random(2);

        new float:dir = getDirection();
        new float:angle;

        if (randDir == 0) {
            angle = dir + 1.5708;
        } 
        else {
            angle = dir - 1.5708;
        }

        rotate(angle);
        wait(1.0);
        walk();
    }
}

// ============================
// EVITAR COLISIONES
// ============================
stock evitarColisiones() {

    new touched = getTouched();

    if ((touched & ITEM_WARRIOR) != 0) {

        stand();
        wait(1.0);

        new randDir = random(2);

        new float:dir = getDirection();
        new float:angle;

        if (randDir == 0) {
            angle = dir + 1.5708;
        } 
        else {
            angle = dir - 1.5708;
        }

        rotate(angle);
        wait(1.0);
        walk();
    }
}

// ============================
// MAIN
// ============================
main() {

    if (getID() == 2) {

        iniciarBot();

        new headDir = 1;
        new float:headAngle = 0.0;

        while (true) {

            if (!isWalking()) {
                walk();
            }

            escanear(headAngle, headDir);
            atacar();
            evitarParedes();
            evitarColisiones();

            wait(0.04);
        }
    } 
    else {
        while (true) {
            wait(1.0);
        }
    }
}