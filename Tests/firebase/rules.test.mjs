import { readFileSync } from 'node:fs';
import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc, serverTimestamp, writeBatch } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-uspevai-chat', firestore: { host: '127.0.0.1', port: 8088, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
});
after(async () => { await env?.cleanup(); });
const db = uid => env.authenticatedContext(uid).firestore();
const message = senderID => ({ senderID, kind: 'text', text: 'Привет!', payload: '', sentAt: serverTimestamp() });

test('both participants send, recipient discovers inbox, outsider cannot read or inject', async () => {
  const alice = db('alice'), bob = db('bob'), eve = db('eve');
  await assertSucceeds(setDoc(doc(alice, 'chats/alice_bob'), { participants: ['alice', 'bob'] }));
  for (const [uid, client] of [['alice', alice], ['bob', bob]]) {
    const batch = writeBatch(client);
    batch.set(doc(client, `chats/alice_bob/messages/${uid}`), message(uid));
    batch.update(doc(client, 'chats/alice_bob'), { updatedAt: serverTimestamp(), lastMessage: 'Привет!' });
    await assertSucceeds(batch.commit());
  }
  const inbox = await assertSucceeds(getDocs(query(collection(bob, 'chats'), where('participants', 'array-contains', 'bob'))));
  assert.equal(inbox.size, 1);
  await assertSucceeds(getDoc(doc(bob, 'chats/alice_bob/messages/alice')));
  await assertFails(getDoc(doc(eve, 'chats/alice_bob')));
  await assertFails(getDoc(doc(eve, 'chats/alice_bob/messages/alice')));
  await assertFails(setDoc(doc(eve, 'chats/alice_bob/messages/attack'), message('eve')));
  await assertFails(setDoc(doc(alice, 'chats/alice_bob/messages/forged'), message('bob')));
  await assertFails(updateDoc(doc(alice, 'chats/alice_bob'), { participants: ['alice', 'eve'] }));
});

test('legacy participant order can be normalized without adding a participant', async () => {
  const client = db('carol');
  await assertSucceeds(setDoc(doc(client, 'chats/carol_dan'), { participants: ['dan', 'carol'] }));
  await assertSucceeds(setDoc(doc(client, 'chats/carol_dan'), { participants: ['carol', 'dan'] }, { merge: true }));
  await assertFails(updateDoc(doc(client, 'chats/carol_dan'), { participants: ['carol', 'carol'] }));
});

test('invalid chat, unsigned access, oversized and malformed message denied', async () => {
  const client = db('alice');
  await assertSucceeds(setDoc(doc(client, 'chats/alice_bob'), { participants: ['alice', 'bob'] }, { merge: true }));
  await assertFails(setDoc(doc(client, 'chats/self'), { participants: ['alice', 'alice'] }));
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'chats')));
  await assertFails(setDoc(doc(client, 'chats/alice_bob/messages/huge'), { ...message('alice'), payload: 'x'.repeat(80001) }));
  await assertFails(setDoc(doc(client, 'chats/alice_bob/messages/badTime'), { ...message('alice'), sentAt: 'tomorrow' }));
  await assertFails(setDoc(doc(client, 'chats/alice_bob/messages/extra'), { ...message('alice'), admin: true }));
});

test('schedule, grades and analytics attachments pass with server timestamp', async () => {
  const client = db('sender');
  await assertSucceeds(setDoc(doc(client, 'chats/sender_receiver'), { participants: ['receiver', 'sender'] }));
  for (const kind of ['schedule', 'grades', 'analytics']) {
    await assertSucceeds(setDoc(doc(client, `chats/sender_receiver/messages/${kind}`), { ...message('sender'), kind, payload: JSON.stringify({ preview: 'Учебная карточка' }) }));
  }
});
