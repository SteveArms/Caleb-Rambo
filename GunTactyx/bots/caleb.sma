#include "core"
#include "math"
#include "bots"

new const float:PI     = 3.14159;
new const float:TWO_PI = 6.28318;
new const float:MC     = 1.2;    // cooldown walk/stand (1s + margen)
new const float:SPEAK_CD = 0.3;  // cooldown speak (0.25s + margen)
new const float:ROT_SPEED = 1.5708; // PI/2 rad/s

new const float:ARRIVE_DIST = 2.5;
new const float:SCAN_STEP   = 0.7854; // 45 grados en radianes

new const RADIO_CH        = 0;
new const MSG_ENEMY_FOUND = 200;

new float:spawnX = 0.0;
new float:spawnY = 0.0;

// ── Math ─────────────────────────────────────────────────────────

stock float:wrapPi(float:a) {
    while (a >  PI) a -= TWO_PI;
    while (a < -PI) a += TWO_PI;
    return a;
}

stock float:myAtan2(float:y, float:x) {
    if (x > -0.0001 && x < 0.0001)
        return (y >= 0.0) ? PI / 2.0 : -PI / 2.0;
    new float:a = atan(y / x);
    if (x < 0.0) return (y >= 0.0) ? a + PI : a - PI;
    return a;
}

stock float:dist2D(float:ax, float:ay, float:bx, float:by) {
    new float:dx = bx - ax;
    new float:dy = by - ay;
    return sqrt(dx*dx + dy*dy);
}

// ── Movimiento ───────────────────────────────────────────────────

stock doStand() {
    if (!isStanding()) { stand(); wait(MC); }
}

stock faceAngle(float:target) {
    doStand();
    new float:diff = wrapPi(target - getDirection());
    rotate(getDirection() + diff);
    new float:t = (diff < 0.0 ? -diff : diff) / ROT_SPEED;
    if (t < 0.2) t = 0.2;
    wait(t);
}

stock bool:walkTo(float:tx, float:ty) {
    new float:x, y, z;
    getLocation(x, y, z);
    if (dist2D(x, y, tx, ty) < ARRIVE_DIST) { doStand(); return true; }

    faceAngle(myAtan2(ty - y, tx - x));
    walk();
    wait(MC);

    new stuckCount = 0;
    new float:prevX = x;
    new float:prevY = y;

    for (;;) {
        getLocation(x, y, z);
        if (dist2D(x, y, tx, ty) < ARRIVE_DIST) { stand(); wait(MC); return true; }

        if (dist2D(x, y, prevX, prevY) < 0.3) {
            stuckCount++;
            if (stuckCount >= 5) {
                stand(); wait(MC);
                faceAngle(getDirection() + PI / 2.0);
                walk(); wait(MC); wait(1.5);
                stand(); wait(MC);
                return false;
            }
        } else {
            stuckCount = 0;
            prevX = x; prevY = y;
        }

        new float:newA = myAtan2(ty - y, tx - x);
        new float:diff = wrapPi(newA - getDirection());
        if (diff > PI/4.0 || diff < -(PI/4.0)) {
            stand(); wait(MC);
            faceAngle(newA);
            walk(); wait(MC);
        }
        wait(0.5);
    }
    return false;
}

stock walkToRetry(float:tx, float:ty, n) {
    new i;
    for (i = 0; i < n; i++) {
        if (walkTo(tx, ty)) return;
    }
    doStand();
}

// ── Radio ────────────────────────────────────────────────────────

// Protocolo: MSG_ENEMY_FOUND (200), yaw*100 (int), dist*100 (int)
stock reportEnemy(float:yaw, float:dist) {
    speak(RADIO_CH, MSG_ENEMY_FOUND);
    wait(SPEAK_CD);
    speak(RADIO_CH, floatround(yaw * 100.0));
    wait(SPEAK_CD);
    speak(RADIO_CH, floatround(dist * 100.0));
    wait(SPEAK_CD);
}

// ── Deteccion ────────────────────────────────────────────────────

// watch() tiene FoV de 60 grados total (PI/6 desde el centro)
// yaw retornado es relativo a la cabeza — convertir a absoluto
stock bool:scanAndReport() {
    new item    = ITEM_WARRIOR | ITEM_ENEMY;
    new float:d = 0.0;
    new float:yaw;
    watch(item, d, yaw);
    if (item == (ITEM_WARRIOR | ITEM_ENEMY)) {
        new float:absYaw = wrapPi(getDirection() + getTorsoYaw() + getHeadYaw() + yaw);
        reportEnemy(absYaw, d);
        return true;
    }
    return false;
}

// 8 posiciones x 45 grados = 360 de cobertura
stock bool:scan360() {
    doStand();
    new float:baseDir = getDirection();
    new i;
    for (i = 0; i < 8; i++) {
        faceAngle(baseDir + SCAN_STEP * float(i));
        if (scanAndReport()) return true;
    }
    return false;
}

// ── Main ─────────────────────────────────────────────────────────

main() {
    wait(0.1);
    new float:x, y, z;
    getLocation(x, y, z);
    spawnX = x;
    spawnY = y;

    wait(0.5); // no chocar con bots del circulo al arrancar

    // Punto intermedio spawn -> centro
    new float:midX = spawnX / 2.0;
    new float:midY = spawnY / 2.0;

    // Loop de patrulla: spawn -> mid -> centro -> mid -> spawn -> repeat
    for (;;) {
        // Ir al punto intermedio
        walkToRetry(midX, midY, 3);
        scan360();

        // Ir al centro
        walkToRetry(0.0, 0.0, 5);
        scan360();

        // Volver pasando por el punto intermedio
        walkToRetry(midX, midY, 3);
        scan360();

        // Volver al spawn
        walkToRetry(spawnX, spawnY, 5);
        scan360();

        // Pausa antes de la siguiente ronda
        wait(1.0);
    }
}
