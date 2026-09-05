'use strict';

// Exercise the shipped bridge in a mock DOM without starting Godot or fetching files.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '../web/mobile_shell.html'), 'utf8');
const bridgeSource = shell.match(/<script>\s*([\s\S]*?)<\/script>/)?.[1];
assert.ok(bridgeSource, 'The export shell contains its inline mobile bridge');

function eventTarget(properties = {}) {
  const listeners = new Map();
  return Object.assign(properties, {
    addEventListener(type, callback) {
      if (!listeners.has(type)) listeners.set(type, []);
      listeners.get(type).push(callback);
    },
    dispatch(type) {
      for (const callback of listeners.get(type) || []) {
        callback({ type, preventDefault() {} });
      }
    },
  });
}

function createPage({ width = 844, height = 390, touch = true, focused = false, hidden = false } = {}) {
  const frames = [];
  const frame = { style: {} };
  const turnDevice = { hidden: true };
  const canvas = eventTarget({
    width: 0,
    height: 0,
    getBoundingClientRect() {
      return { width: parseFloat(frame.style.width), height: parseFloat(frame.style.height) };
    },
  });
  const elements = { canvas, 'game-frame': frame, 'turn-device': turnDevice };
  const pointer = eventTarget({ matches: touch });
  const viewport = eventTarget({ width, height });
  const document = eventTarget({
    hidden,
    hasFocus: () => focused,
    getElementById: id => elements[id],
  });
  const window = eventTarget({
    location: { search: '' },
    innerWidth: width,
    innerHeight: height,
    devicePixelRatio: 3,
    visualViewport: viewport,
    matchMedia: () => pointer,
  });
  class ResizeObserver {
    observe() {}
  }
  window.ResizeObserver = ResizeObserver;
  vm.runInNewContext(bridgeSource, {
    document,
    window,
    navigator: { maxTouchPoints: touch ? 5 : 0 },
    URLSearchParams,
    ResizeObserver,
    requestAnimationFrame: callback => frames.push(callback),
  }, { filename: 'web/mobile_shell.html' });

  return {
    window, document, viewport, frame, turnDevice, canvas,
    state: window.darioMobile,
    resize(nextWidth, nextHeight, event = 'resize') {
      viewport.width = window.innerWidth = nextWidth;
      viewport.height = window.innerHeight = nextHeight;
      window.dispatch(event);
      viewport.dispatch('resize');
    },
    flushFrames() {
      while (frames.length) frames.shift()();
    },
  };
}

test('a visible but unfocused mobile page starts playable', () => {
  const page = createPage({ focused: false });
  assert.deepEqual({ ...page.state }, {
    isTouch: true, portrait: false, pageVisible: true, pauseRevision: 0,
  });
  assert.equal(page.turnDevice.hidden, true);
});

test('focus noise and landscape browser chrome resizing do not interrupt gameplay', () => {
  const page = createPage();
  const retainedBridge = page.state;
  for (let index = 0; index < 5; index++) {
    page.window.dispatch('blur');
    page.resize(844, 340 + index * 10);
    page.window.dispatch('focus');
    page.window.dispatch('pageshow');
  }
  page.flushFrames();
  assert.equal(page.window.darioMobile, retainedBridge);
  assert.equal(page.state.pageVisible, true);
  assert.equal(page.state.portrait, false);
  assert.equal(page.state.pauseRevision, 0);
  assert.equal(page.turnDevice.hidden, true);
  assert.equal(page.canvas.width, 1688);
  assert.equal(page.canvas.height, 760);
});

test('portrait overlay and pause revision follow actual portrait entry', () => {
  const page = createPage();
  page.resize(390, 844, 'orientationchange');
  assert.equal(page.turnDevice.hidden, false);
  assert.equal(page.state.portrait, true);
  assert.equal(page.state.pauseRevision, 1);
  page.resize(390, 780);
  page.window.dispatch('orientationchange');
  assert.equal(page.state.pauseRevision, 1);
  page.resize(844, 390, 'orientationchange');
  assert.equal(page.turnDevice.hidden, true);
  assert.equal(page.state.portrait, false);
  assert.equal(page.state.pauseRevision, 1);
  page.resize(390, 844, 'orientationchange');
  assert.equal(page.state.pauseRevision, 2);
});

test('portrait-to-landscape initialization leaves a visible playable page', () => {
  const page = createPage({ width: 390, height: 844, focused: false });
  assert.equal(page.state.pauseRevision, 1);
  assert.equal(page.turnDevice.hidden, false);
  page.resize(844, 390, 'orientationchange');
  page.window.dispatch('blur');
  assert.equal(page.state.pageVisible, true);
  assert.equal(page.state.portrait, false);
  assert.equal(page.turnDevice.hidden, true);
  assert.equal(page.state.pauseRevision, 1);
});

test('hidden document and pagehide produce one interruption until both restore', () => {
  const page = createPage();
  page.document.hidden = true;
  page.document.dispatch('visibilitychange');
  page.window.dispatch('pagehide');
  assert.equal(page.state.pageVisible, false);
  assert.equal(page.state.pauseRevision, 1);
  page.window.dispatch('pageshow');
  assert.equal(page.state.pageVisible, false);
  page.document.hidden = false;
  page.document.dispatch('visibilitychange');
  assert.equal(page.state.pageVisible, true);
  assert.equal(page.state.pauseRevision, 1);
  page.window.dispatch('blur');
  assert.equal(page.state.pauseRevision, 1);
});

test('pagehide remains blocking when visibility events arrive in the opposite order', () => {
  const page = createPage();
  page.window.dispatch('pagehide');
  page.document.hidden = true;
  page.document.dispatch('visibilitychange');
  assert.equal(page.state.pageVisible, false);
  assert.equal(page.state.pauseRevision, 1);
  page.document.hidden = false;
  page.document.dispatch('visibilitychange');
  assert.equal(page.state.pageVisible, false);
  page.window.dispatch('pageshow');
  assert.equal(page.state.pageVisible, true);
  assert.equal(page.state.pauseRevision, 1);
  page.window.dispatch('pagehide');
  assert.equal(page.state.pauseRevision, 2);
});

test('interruptions remain observable when the game receives no intermediate frame', () => {
  const page = createPage();
  page.resize(390, 844, 'orientationchange');
  page.resize(844, 390, 'orientationchange');
  assert.equal(page.state.portrait, false);
  assert.equal(page.state.pauseRevision, 1);
  page.document.hidden = true;
  page.document.dispatch('visibilitychange');
  page.document.hidden = false;
  page.document.dispatch('visibilitychange');
  assert.equal(page.state.pageVisible, true);
  assert.equal(page.state.pauseRevision, 2);
  page.flushFrames();
  assert.equal(page.state.pauseRevision, 2);
});

test('a narrow desktop window does not show a phone orientation blocker', () => {
  const page = createPage({ width: 390, height: 844, touch: false });
  assert.equal(page.state.isTouch, false);
  assert.equal(page.state.portrait, false);
  assert.equal(page.turnDevice.hidden, true);
  assert.equal(page.state.pauseRevision, 0);
});
