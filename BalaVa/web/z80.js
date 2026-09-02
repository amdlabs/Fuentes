// Nucleo Z80 + ULA de ZX Spectrum 48K, lo justo para mover BalaVa.
// Se usa igual desde el navegador (artefacto) que desde node (pruebas).
(function (raiz) {
  'use strict';

  var S = 0x80, Z = 0x40, F5 = 0x20, H = 0x10, F3 = 0x08, PV = 0x04, N = 0x02, C = 0x01;

  var SZ53 = new Uint8Array(256), SZ53P = new Uint8Array(256), PAR = new Uint8Array(256);
  for (var i = 0; i < 256; i++) {
    var p = 0, j = i;
    for (var k = 0; k < 8; k++) { p ^= j & 1; j >>= 1; }
    PAR[i] = p ? 0 : PV;
    SZ53[i] = (i & (S | F5 | F3)) | (i === 0 ? Z : 0);
    SZ53P[i] = SZ53[i] | PAR[i];
  }

  function Spectrum() {
    this.mem = new Uint8Array(65536);
    this.teclas = {};                 // "fila,bit" -> pulsada
    this.borde = 0;
    this.altavoz = 0;
    this.ay = new Uint8Array(16);      // registros del AY del 128K
    this.ayReg = 0;
    this.cambios = [];                // [t, nivel] del altavoz dentro del frame
    this.tFrame = 0;
    this.reset();
  }

  Spectrum.TICKS_FRAME = 69888;

  // --- matriz de teclado: semifila (bit de A8..A15) y bit de datos -----
  Spectrum.MATRIZ = {
    CAPS: [0, 0], Z: [0, 1], X: [0, 2], C: [0, 3], V: [0, 4],
    A: [1, 0], S: [1, 1], D: [1, 2], F: [1, 3], G: [1, 4],
    Q: [2, 0], W: [2, 1], E: [2, 2], R: [2, 3], T: [2, 4],
    '1': [3, 0], '2': [3, 1], '3': [3, 2], '4': [3, 3], '5': [3, 4],
    '0': [4, 0], '9': [4, 1], '8': [4, 2], '7': [4, 3], '6': [4, 4],
    P: [5, 0], O: [5, 1], I: [5, 2], U: [5, 3], Y: [5, 4],
    ENTER: [6, 0], L: [6, 1], K: [6, 2], J: [6, 3], HH: [6, 4],
    SPACE: [7, 0], SYM: [7, 1], M: [7, 2], NN: [7, 3], B: [7, 4]
  };

  var p = Spectrum.prototype;

  p.reset = function () {
    this.a = this.f = this.b = this.c = this.d = this.e = this.h = this.l = 0;
    this.a_ = this.f_ = this.b_ = this.c_ = this.d_ = this.e_ = this.h_ = this.l_ = 0;
    this.ix = this.iy = 0;
    this.i = 0x3f; this.r = 0;
    this.sp = 0xffff; this.pc = 0;
    this.iff1 = this.iff2 = 0; this.im = 1; this.halted = false;
    this.t = 0;
  };

  // --- memoria y puertos ----------------------------------------------
  p.leer = function (dir) { return this.mem[dir & 0xffff]; };
  p.escribir = function (dir, v) {
    dir &= 0xffff;
    if (dir >= 0x4000) this.mem[dir] = v & 0xff;
  };
  p.leer16 = function (dir) { return this.leer(dir) | (this.leer(dir + 1) << 8); };
  p.escribir16 = function (dir, v) { this.escribir(dir, v & 0xff); this.escribir(dir + 1, v >> 8); };

  p.entrada = function (puerto) {
    if (puerto & 1) return 0xff;                    // solo nos interesa la ULA
    var alto = (puerto >> 8) & 0xff, res = 0xff;
    for (var tecla in this.teclas) {
      if (!this.teclas[tecla]) continue;
      var m = Spectrum.MATRIZ[tecla];
      if (!m) continue;
      if (!(alto & (1 << m[0]))) res &= ~(1 << m[1]) & 0xff;
    }
    return res;
  };

  p.salida = function (puerto, v) {
    if ((puerto & 0xc002) === 0xc000) { this.ayReg = v & 0x0f; return; }   // 0xFFFD
    if ((puerto & 0xc002) === 0x8000) { this.ay[this.ayReg] = v; return; } // 0xBFFD
    if (puerto & 1) return;
    this.borde = v & 7;
    var nivel = (v >> 4) & 1;
    if (nivel !== this.altavoz) {
      this.altavoz = nivel;
      this.cambios.push([this.t, nivel]);
    }
  };

  // --- utilidades de instruccion ---------------------------------------
  p.busca = function () { var v = this.leer(this.pc); this.pc = (this.pc + 1) & 0xffff; return v; };
  p.busca16 = function () { var v = this.leer16(this.pc); this.pc = (this.pc + 2) & 0xffff; return v; };
  p.push = function (v) {
    this.sp = (this.sp - 2) & 0xffff;
    this.escribir16(this.sp, v);
  };
  p.pop = function () { var v = this.leer16(this.sp); this.sp = (this.sp + 2) & 0xffff; return v; };

  p.hl = function () { return (this.h << 8) | this.l; };
  p.setHl = function (v) { this.h = (v >> 8) & 0xff; this.l = v & 0xff; };
  p.bc = function () { return (this.b << 8) | this.c; };
  p.de = function () { return (this.d << 8) | this.e; };

  // aritmetica
  p.add8 = function (v) {
    var r = this.a + v;
    this.f = (r & 0xff ? 0 : Z) | (r & S) | (r & (F5 | F3)) |
      ((this.a ^ v ^ r) & H) | (((this.a ^ v ^ 0x80) & (this.a ^ r) & 0x80) ? PV : 0) |
      (r > 0xff ? C : 0);
    this.a = r & 0xff;
  };
  p.adc8 = function (v) {
    var cy = this.f & C, r = this.a + v + cy;
    this.f = (r & 0xff ? 0 : Z) | (r & S) | (r & (F5 | F3)) |
      ((this.a ^ v ^ r) & H) | (((this.a ^ v ^ 0x80) & (this.a ^ r) & 0x80) ? PV : 0) |
      (r > 0xff ? C : 0);
    this.a = r & 0xff;
  };
  p.sub8 = function (v) {
    var r = this.a - v;
    this.f = N | (r & 0xff ? 0 : Z) | (r & S) | (r & (F5 | F3)) |
      ((this.a ^ v ^ r) & H) | (((this.a ^ v) & (this.a ^ r) & 0x80) ? PV : 0) |
      (r < 0 ? C : 0);
    this.a = r & 0xff;
  };
  p.sbc8 = function (v) {
    var cy = this.f & C, r = this.a - v - cy;
    this.f = N | (r & 0xff ? 0 : Z) | (r & S) | (r & (F5 | F3)) |
      ((this.a ^ v ^ r) & H) | (((this.a ^ v) & (this.a ^ r) & 0x80) ? PV : 0) |
      (r < 0 ? C : 0);
    this.a = r & 0xff;
  };
  p.cp8 = function (v) {
    var r = (this.a - v) & 0xff, rr = this.a - v;
    this.f = N | (r ? 0 : Z) | (r & S) | (v & (F5 | F3)) |
      ((this.a ^ v ^ r) & H) | (((this.a ^ v) & (this.a ^ r) & 0x80) ? PV : 0) |
      (rr < 0 ? C : 0);
  };
  p.and8 = function (v) { this.a &= v; this.f = SZ53P[this.a] | H; };
  p.or8 = function (v) { this.a |= v; this.f = SZ53P[this.a]; };
  p.xor8 = function (v) { this.a ^= v; this.f = SZ53P[this.a]; };
  p.inc8 = function (v) {
    v = (v + 1) & 0xff;
    this.f = (this.f & C) | SZ53[v] | ((v & 0x0f) ? 0 : H) | (v === 0x80 ? PV : 0);
    return v;
  };
  p.dec8 = function (v) {
    var r = (v - 1) & 0xff;
    this.f = (this.f & C) | N | SZ53[r] | ((v & 0x0f) ? 0 : H) | (r === 0x7f ? PV : 0);
    return r;
  };
  p.addHl = function (rp, v) {
    var r = rp + v;
    this.f = (this.f & (S | Z | PV)) | ((rp ^ v ^ r) >> 8 & H) |
      ((r >> 8) & (F5 | F3)) | (r > 0xffff ? C : 0);
    return r & 0xffff;
  };
  p.sbcHl = function (v) {
    var hl = this.hl(), cy = this.f & C, r = hl - v - cy;
    this.f = N | ((r & 0xffff) ? 0 : Z) | ((r >> 8) & (S | F5 | F3)) |
      (((hl ^ v ^ r) >> 8) & H) | (((hl ^ v) & (hl ^ r) & 0x8000) ? PV : 0) |
      (r < 0 ? C : 0);
    this.setHl(r & 0xffff);
  };
  p.adcHl = function (v) {
    var hl = this.hl(), cy = this.f & C, r = hl + v + cy;
    this.f = ((r & 0xffff) ? 0 : Z) | ((r >> 8) & (S | F5 | F3)) |
      (((hl ^ v ^ r) >> 8) & H) | (((hl ^ v ^ 0x8000) & (hl ^ r) & 0x8000) ? PV : 0) |
      (r > 0xffff ? C : 0);
    this.setHl(r & 0xffff);
  };

  // acceso a registro por indice (con sustitucion de HL por IX/IY)
  p.getR = function (n, pref, dir) {
    switch (n) {
      case 0: return this.b; case 1: return this.c; case 2: return this.d; case 3: return this.e;
      case 4: return pref ? (pref === 1 ? (this.ix >> 8) & 0xff : (this.iy >> 8) & 0xff) : this.h;
      case 5: return pref ? (pref === 1 ? this.ix & 0xff : this.iy & 0xff) : this.l;
      case 6: return this.leer(dir === undefined ? this.hl() : dir);
      case 7: return this.a;
    }
  };
  p.setR = function (n, v, pref, dir) {
    v &= 0xff;
    switch (n) {
      case 0: this.b = v; break; case 1: this.c = v; break;
      case 2: this.d = v; break; case 3: this.e = v; break;
      case 4:
        if (!pref) this.h = v;
        else if (pref === 1) this.ix = (v << 8) | (this.ix & 0xff);
        else this.iy = (v << 8) | (this.iy & 0xff);
        break;
      case 5:
        if (!pref) this.l = v;
        else if (pref === 1) this.ix = (this.ix & 0xff00) | v;
        else this.iy = (this.iy & 0xff00) | v;
        break;
      case 6: this.escribir(dir === undefined ? this.hl() : dir, v); break;
      case 7: this.a = v; break;
    }
  };

  p.cond = function (n) {
    switch (n) {
      case 0: return !(this.f & Z); case 1: return !!(this.f & Z);
      case 2: return !(this.f & C); case 3: return !!(this.f & C);
      case 4: return !(this.f & PV); case 5: return !!(this.f & PV);
      case 6: return !(this.f & S); case 7: return !!(this.f & S);
    }
  };

  p.getRp = function (n, pref) {
    switch (n) {
      case 0: return this.bc(); case 1: return this.de();
      case 2: return pref ? (pref === 1 ? this.ix : this.iy) : this.hl();
      case 3: return this.sp;
    }
  };
  p.setRp = function (n, v, pref) {
    v &= 0xffff;
    switch (n) {
      case 0: this.b = v >> 8; this.c = v & 0xff; break;
      case 1: this.d = v >> 8; this.e = v & 0xff; break;
      case 2: if (!pref) this.setHl(v); else if (pref === 1) this.ix = v; else this.iy = v; break;
      case 3: this.sp = v; break;
    }
  };

  // --- ejecuta una instruccion ------------------------------------------
  p.paso = function () {
    if (this.halted) { this.t += 4; return; }
    this.r = (this.r & 0x80) | ((this.r + 1) & 0x7f);
    var op = this.busca();
    if (op === 0xdd || op === 0xfd) {
      var pref = op === 0xdd ? 1 : 2;
      this.r = (this.r & 0x80) | ((this.r + 1) & 0x7f);
      this.t += 4;
      this.ejecuta(this.busca(), pref);
    } else {
      this.ejecuta(op, 0);
    }
  };

  p.dirIdx = function (pref) {          // (IX+d) / (IY+d)
    var d = this.busca();
    if (d > 127) d -= 256;
    this.t += 8;
    return (((pref === 1 ? this.ix : this.iy) + d) & 0xffff);
  };

  p.ejecuta = function (op, pref) {
    var x = op >> 6, y = (op >> 3) & 7, z = op & 7, q = y & 1, pp = y >> 1;
    var dir, v, t;

    if (op === 0xcb) { this.cb(pref); return; }
    if (op === 0xed) { this.ed(); return; }

    switch (x) {
      case 0:
        switch (z) {
          case 0:
            if (y === 0) { this.t += 4; }
            else if (y === 1) {                       // EX AF,AF'
              t = this.a; this.a = this.a_; this.a_ = t;
              t = this.f; this.f = this.f_; this.f_ = t; this.t += 4;
            } else if (y === 2) {                     // DJNZ
              var d = this.busca(); if (d > 127) d -= 256;
              this.b = (this.b - 1) & 0xff;
              if (this.b) { this.pc = (this.pc + d) & 0xffff; this.t += 13; } else this.t += 8;
            } else if (y === 3) {                     // JR d
              var d2 = this.busca(); if (d2 > 127) d2 -= 256;
              this.pc = (this.pc + d2) & 0xffff; this.t += 12;
            } else {                                  // JR cc,d
              var d3 = this.busca(); if (d3 > 127) d3 -= 256;
              if (this.cond(y - 4)) { this.pc = (this.pc + d3) & 0xffff; this.t += 12; }
              else this.t += 7;
            }
            break;
          case 1:
            if (!q) { this.setRp(pp, this.busca16(), pref); this.t += 10; }
            else { this.setRp(2, this.addHl(this.getRp(2, pref), this.getRp(pp, pref)), pref); this.t += 11; }
            break;
          case 2:
            if (!q) {
              if (pp === 0) { this.escribir(this.bc(), this.a); this.t += 7; }          // LD (BC),A
              else if (pp === 1) { this.escribir(this.de(), this.a); this.t += 7; }     // LD (DE),A
              else if (pp === 2) { this.escribir16(this.busca16(), this.getRp(2, pref)); this.t += 16; }
              else { this.escribir(this.busca16(), this.a); this.t += 13; }             // LD (nn),A
            } else {
              if (pp === 0) { this.a = this.leer(this.bc()); this.t += 7; }             // LD A,(BC)
              else if (pp === 1) { this.a = this.leer(this.de()); this.t += 7; }        // LD A,(DE)
              else if (pp === 2) { this.setRp(2, this.leer16(this.busca16()), pref); this.t += 16; }
              else { this.a = this.leer(this.busca16()); this.t += 13; }                // LD A,(nn)
            }
            break;
          case 3:
            v = this.getRp(pp, pref);
            this.setRp(pp, q ? v - 1 : v + 1, pref);
            this.t += 6;
            break;
          case 4:
            if (y === 6 && pref) { dir = this.dirIdx(pref); this.escribir(dir, this.inc8(this.leer(dir))); this.t += 11; }
            else if (y === 6) { this.escribir(this.hl(), this.inc8(this.leer(this.hl()))); this.t += 11; }
            else { this.setR(y, this.inc8(this.getR(y, pref)), pref); this.t += 4; }
            break;
          case 5:
            if (y === 6 && pref) { dir = this.dirIdx(pref); this.escribir(dir, this.dec8(this.leer(dir))); this.t += 11; }
            else if (y === 6) { this.escribir(this.hl(), this.dec8(this.leer(this.hl()))); this.t += 11; }
            else { this.setR(y, this.dec8(this.getR(y, pref)), pref); this.t += 4; }
            break;
          case 6:
            if (y === 6 && pref) { dir = this.dirIdx(pref); this.escribir(dir, this.busca()); this.t += 11; }
            else if (y === 6) { this.escribir(this.hl(), this.busca()); this.t += 10; }
            else { this.setR(y, this.busca(), pref); this.t += 7; }
            break;
          case 7:
            this.rotaAcc(y);
            this.t += 4;
            break;
        }
        break;

      case 1:
        if (op === 0x76) { this.halted = true; this.t += 4; break; }
        if (pref && (y === 6 || z === 6)) {
          dir = this.dirIdx(pref);
          if (z === 6) this.setR(y, this.leer(dir), 0);
          else this.escribir(dir, this.getR(z, 0));
          this.t += 7;
        } else {
          this.setR(y, this.getR(z, pref), pref);
          this.t += (y === 6 || z === 6) ? 7 : 4;
        }
        break;

      case 2:
        if (pref && z === 6) { dir = this.dirIdx(pref); v = this.leer(dir); this.t += 7; }
        else { v = this.getR(z, pref); this.t += (z === 6) ? 7 : 4; }
        this.alu(y, v);
        break;

      case 3:
        switch (z) {
          case 0:
            if (this.cond(y)) { this.pc = this.pop(); this.t += 11; } else this.t += 5;
            break;
          case 1:
            if (!q) {
              v = this.pop();
              if (pp === 3) { this.a = v >> 8; this.f = v & 0xff; }
              else this.setRp(pp, v, pref);
              this.t += 10;
            } else if (pp === 0) { this.pc = this.pop(); this.t += 10; }
            else if (pp === 1) {                       // EXX
              t = this.b; this.b = this.b_; this.b_ = t;
              t = this.c; this.c = this.c_; this.c_ = t;
              t = this.d; this.d = this.d_; this.d_ = t;
              t = this.e; this.e = this.e_; this.e_ = t;
              t = this.h; this.h = this.h_; this.h_ = t;
              t = this.l; this.l = this.l_; this.l_ = t;
              this.t += 4;
            } else if (pp === 2) { this.pc = this.getRp(2, pref); this.t += 4; }
            else { this.sp = this.getRp(2, pref); this.t += 6; }
            break;
          case 2:
            v = this.busca16();
            if (this.cond(y)) this.pc = v;
            this.t += 10;
            break;
          case 3:
            if (y === 0) { this.pc = this.busca16(); this.t += 10; }
            else if (y === 2) { v = this.busca(); this.salida((this.a << 8) | v, this.a); this.t += 11; }
            else if (y === 3) { v = this.busca(); this.a = this.entrada((this.a << 8) | v); this.t += 11; }
            else if (y === 4) {                        // EX (SP),HL
              v = this.leer16(this.sp);
              this.escribir16(this.sp, this.getRp(2, pref));
              this.setRp(2, v, pref); this.t += 19;
            } else if (y === 5) {                      // EX DE,HL
              t = this.d; this.d = this.h; this.h = t;
              t = this.e; this.e = this.l; this.l = t; this.t += 4;
            } else if (y === 6) { this.iff1 = this.iff2 = 0; this.t += 4; }
            else { this.iff1 = this.iff2 = 1; this.t += 4; }
            break;
          case 4:
            v = this.busca16();
            if (this.cond(y)) { this.push(this.pc); this.pc = v; this.t += 17; } else this.t += 10;
            break;
          case 5:
            if (!q) {
              this.push(pp === 3 ? ((this.a << 8) | this.f) : this.getRp(pp, pref));
              this.t += 11;
            } else if (pp === 0) { v = this.busca16(); this.push(this.pc); this.pc = v; this.t += 17; }
            break;
          case 6:
            this.alu(y, this.busca()); this.t += 7;
            break;
          case 7:
            this.push(this.pc); this.pc = y * 8; this.t += 11;
            break;
        }
        break;
    }
  };

  p.alu = function (n, v) {
    switch (n) {
      case 0: this.add8(v); break; case 1: this.adc8(v); break;
      case 2: this.sub8(v); break; case 3: this.sbc8(v); break;
      case 4: this.and8(v); break; case 5: this.xor8(v); break;
      case 6: this.or8(v); break; case 7: this.cp8(v); break;
    }
  };

  p.rotaAcc = function (n) {
    var a = this.a, cy = this.f & C, r;
    switch (n) {
      case 0: r = ((a << 1) | (a >> 7)) & 0xff; this.f = (this.f & (S | Z | PV)) | (r & (F5 | F3)) | (a >> 7); this.a = r; break;
      case 1: r = ((a >> 1) | (a << 7)) & 0xff; this.f = (this.f & (S | Z | PV)) | (r & (F5 | F3)) | (a & 1); this.a = r; break;
      case 2: r = ((a << 1) | cy) & 0xff; this.f = (this.f & (S | Z | PV)) | (r & (F5 | F3)) | (a >> 7); this.a = r; break;
      case 3: r = ((a >> 1) | (cy << 7)) & 0xff; this.f = (this.f & (S | Z | PV)) | (r & (F5 | F3)) | (a & 1); this.a = r; break;
      case 4:                                          // DAA
        var c = this.f & C, ajuste = 0;
        if ((this.f & H) || (a & 0x0f) > 9) ajuste |= 0x06;
        if (c || a > 0x99) { ajuste |= 0x60; c = C; }
        if (this.f & N) { r = (a - ajuste) & 0xff; this.f = N | ((a ^ r) & H); }
        else { r = (a + ajuste) & 0xff; this.f = ((a ^ r) & H); }
        this.f |= SZ53P[r] | c; this.a = r; break;
      case 5: this.a = (~a) & 0xff; this.f = (this.f & (S | Z | PV | C)) | H | N | (this.a & (F5 | F3)); break;
      case 6: this.f = (this.f & (S | Z | PV)) | (this.a & (F5 | F3)) | C; break;
      case 7: this.f = (this.f & (S | Z | PV)) | (cy ? H : 0) | (this.a & (F5 | F3)) | (cy ? 0 : C); break;
    }
  };

  // --- prefijo CB --------------------------------------------------------
  p.cb = function (pref) {
    var dir = null, op;
    if (pref) { dir = this.dirIdx(pref); op = this.busca(); }
    else op = this.busca();
    var x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    var v = dir !== null ? this.leer(dir) : this.getR(z, 0);
    var cy = this.f & C, r;
    if (x === 0) {
      switch (y) {
        case 0: r = ((v << 1) | (v >> 7)) & 0xff; this.f = (v >> 7); break;
        case 1: r = ((v >> 1) | (v << 7)) & 0xff; this.f = (v & 1); break;
        case 2: r = ((v << 1) | cy) & 0xff; this.f = (v >> 7); break;
        case 3: r = ((v >> 1) | (cy << 7)) & 0xff; this.f = (v & 1); break;
        case 4: r = (v << 1) & 0xff; this.f = (v >> 7); break;
        case 5: r = ((v >> 1) | (v & 0x80)) & 0xff; this.f = (v & 1); break;
        case 6: r = ((v << 1) | 1) & 0xff; this.f = (v >> 7); break;
        case 7: r = (v >> 1) & 0xff; this.f = (v & 1); break;
      }
      this.f |= SZ53P[r];
      if (dir !== null) { this.escribir(dir, r); if (z !== 6) this.setR(z, r, 0); }
      else this.setR(z, r, 0);
      this.t += (dir !== null || z === 6) ? 15 : 8;
    } else if (x === 1) {                              // BIT
      r = v & (1 << y);
      this.f = (this.f & C) | H | (r ? (r & S) : (Z | PV)) | (v & (F5 | F3));
      this.t += (dir !== null || z === 6) ? 12 : 8;
    } else {                                           // RES / SET
      r = x === 2 ? (v & ~(1 << y)) & 0xff : (v | (1 << y));
      if (dir !== null) { this.escribir(dir, r); if (z !== 6) this.setR(z, r, 0); }
      else this.setR(z, r, 0);
      this.t += (dir !== null || z === 6) ? 15 : 8;
    }
  };

  // --- prefijo ED --------------------------------------------------------
  p.ed = function () {
    this.r = (this.r & 0x80) | ((this.r + 1) & 0x7f);
    var op = this.busca(), x = op >> 6, y = (op >> 3) & 7, z = op & 7, q = y & 1, pp = y >> 1;
    var v;
    if (x === 1) {
      switch (z) {
        case 0:                                        // IN r,(C)
          v = this.entrada(this.bc());
          if (y !== 6) this.setR(y, v, 0);
          this.f = (this.f & C) | SZ53P[v];
          this.t += 12; break;
        case 1:                                        // OUT (C),r
          this.salida(this.bc(), y === 6 ? 0 : this.getR(y, 0));
          this.t += 12; break;
        case 2:
          if (q) this.adcHl(this.getRp(pp, 0)); else this.sbcHl(this.getRp(pp, 0));
          this.t += 15; break;
        case 3:
          v = this.busca16();
          if (q) this.setRp(pp, this.leer16(v), 0); else this.escribir16(v, this.getRp(pp, 0));
          this.t += 20; break;
        case 4:                                        // NEG
          v = this.a; this.a = 0; this.sub8(v); this.t += 8; break;
        case 5:                                        // RETN / RETI
          this.pc = this.pop(); this.iff1 = this.iff2; this.t += 14; break;
        case 6:
          this.im = (y === 0 || y === 4) ? 0 : (y === 2 || y === 6) ? 1 : 2;
          if (y === 3 || y === 7) this.im = 2;
          this.t += 8; break;
        case 7:
          if (y === 0) { this.i = this.a; this.t += 9; }
          else if (y === 1) { this.r = this.a; this.t += 9; }
          else if (y === 2) { this.a = this.i; this.f = (this.f & C) | SZ53[this.a] | (this.iff2 ? PV : 0); this.t += 9; }
          else if (y === 3) { this.a = this.r; this.f = (this.f & C) | SZ53[this.a] | (this.iff2 ? PV : 0); this.t += 9; }
          else this.t += 4;
          break;
      }
    } else if (x === 2 && z <= 3 && y >= 4) {          // bloques LDI/LDD/CPI/...
      this.bloque(y, z);
    } else {
      this.t += 8;                                     // ED sin uso: NOP
    }
  };

  p.bloque = function (y, z) {
    var inc = (y & 1) ? -1 : 1, repetir = y >= 6, v;
    if (z === 0) {                                     // LDI / LDD / LDIR / LDDR
      v = this.leer(this.hl());
      this.escribir(this.de(), v);
      this.setHl((this.hl() + inc) & 0xffff);
      this.setRp(1, (this.de() + inc) & 0xffff, 0);
      this.setRp(0, (this.bc() - 1) & 0xffff, 0);
      var n = this.a + v;
      this.f = (this.f & (S | Z | C)) | (this.bc() ? PV : 0) | (n & F3) | ((n & 2) ? F5 : 0);
      this.t += 16;
      if (repetir && this.bc()) { this.pc = (this.pc - 2) & 0xffff; this.t += 5; }
    } else if (z === 1) {                              // CPI / CPD / CPIR / CPDR
      v = this.leer(this.hl());
      var r = (this.a - v) & 0xff;
      this.setHl((this.hl() + inc) & 0xffff);
      this.setRp(0, (this.bc() - 1) & 0xffff, 0);
      this.f = (this.f & C) | N | SZ53[r] | ((this.a ^ v ^ r) & H) | (this.bc() ? PV : 0);
      this.t += 16;
      if (repetir && this.bc() && r) { this.pc = (this.pc - 2) & 0xffff; this.t += 5; }
    } else {
      this.t += 16;                                    // INI/OUTI y compañia: no se usan
    }
  };

  // --- interrupcion y frame ----------------------------------------------
  p.interrupcion = function () {
    if (!this.iff1) return;
    // al ejecutar HALT el PC ya quedo apuntando a la instruccion siguiente,
    // asi que solo hay que despertar: nada de sumarle uno
    this.halted = false;
    this.iff1 = this.iff2 = 0;
    this.push(this.pc);
    if (this.im === 2) this.pc = this.leer16((this.i << 8) | 0xff);
    else this.pc = 0x0038;
    this.t += 13;
  };

  p.frame = function () {
    this.cambios = [];
    this.t = 0;
    while (this.t < Spectrum.TICKS_FRAME) this.paso();
    this.tFrame = this.t;
    this.interrupcion();
  };

  // --- carga de la partida ------------------------------------------------
  p.cargar = function (rom, pantalla, codigo, org, pc, sp, iy) {
    this.mem.fill(0);
    this.mem.set(rom, 0);
    if (pantalla) this.mem.set(pantalla, 0x4000);
    this.mem.set(codigo, org);
    this.reset();
    this.pc = pc; this.sp = sp; this.iy = iy;
    this.im = 1; this.iff1 = this.iff2 = 1;
  };

  raiz.BalaVa = { Spectrum: Spectrum };
  if (typeof module !== 'undefined' && module.exports) module.exports = raiz.BalaVa;
})(typeof self !== 'undefined' ? self : this);
