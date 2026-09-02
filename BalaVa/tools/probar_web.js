#!/usr/bin/env node
// Comprueba que el Z80 en JavaScript del emulador web se comporta igual que
// el de referencia: se le da el mismo guion de teclas y se compara el estado
// (pantalla y variables del juego) con el volcado que deja tools/estado.py.
'use strict';
const fs = require('fs');
const path = require('path');
const { Spectrum } = require(path.join(__dirname, '..', 'web', 'z80.js'));

const raiz = path.join(__dirname, '..');
const guion = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const rom = fs.readFileSync(path.join(raiz, 'build', 'rom.bin'));
const scr = fs.readFileSync(path.join(raiz, 'dist', 'balava.scr'));
const bin = fs.readFileSync(path.join(raiz, 'build', 'balava.bin'));

const m = new Spectrum();
m.cargar(rom, scr, bin, 0x8000, 0x8000, 0xff00, 0x5c3a);

let fallos = 0;
let n = 0;
for (const paso of guion.pasos) {
  m.teclas = {};
  for (const k of paso.teclas) m.teclas[k] = true;
  for (let i = 0; i < paso.frames; i++) { m.frame(); n++; }
  if (paso.comprobar) {
    const esperado = paso.comprobar;
    for (const [dir, valor] of Object.entries(esperado.vars || {})) {
      const real = m.mem[Number(dir)];
      if (real !== valor) {
        console.log(`  FALLA en el frame ${n}: [${Number(dir).toString(16)}] = ${real}, esperaba ${valor}`);
        fallos++;
      }
    }
    if (esperado.pantalla) {
      const sha = require('crypto').createHash('sha1')
        .update(Buffer.from(m.mem.slice(0x4000, 0x5b00))).digest('hex');
      if (sha !== esperado.pantalla) {
        console.log(`  FALLA en el frame ${n}: la pantalla no coincide (${sha.slice(0, 12)} vs ${esperado.pantalla.slice(0, 12)})`);
        fallos++;
      } else {
        console.log(`  OK frame ${n}: pantalla y variables identicas a las del emulador de referencia`);
      }
    }
  }
}
console.log(fallos ? `${fallos} diferencias` : `sin diferencias en ${n} fotogramas`);
process.exit(fallos ? 1 : 0);
