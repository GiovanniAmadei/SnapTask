// Ogni caso riproduce una chiamata che l'app SnapTask fa davvero (vedi FirebaseService.swift
// in release/1.8), oppure un abuso che le regole devono fermare.
import { test, before, after, beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing'
import { Timestamp, doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc, deleteDoc, arrayUnion, runTransaction, writeBatch } from 'firebase/firestore'

const RULES = readFileSync(new URL('../../../firestore.rules', import.meta.url), 'utf8')
let env

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'snaptask-rules-test', firestore: { rules: RULES } })
})
after(async () => env.cleanup())
beforeEach(async () => env.clearFirestore())

const anon = () => env.unauthenticatedContext().firestore()
const now = () => Timestamp.now()
const ID = '6F1C2D3E-0000-4000-8000-000000000001'

function feedback(overrides = {}) {
  return {
    id: ID, title: 'Aggiungere il tema scuro', description: 'Sarebbe utile la sera.', category: 'feature_request',
    status: 'pending', creationDate: now(), authorId: 'uuid-autore', authorName: 'Giovanni',
    votes: 0, likes: 0, replies: [], ...overrides,
  }
}

function reply(overrides = {}) {
  return {
    id: 'R-1', content: 'Grazie, lo valutiamo.', authorId: 'uuid-dev', authorName: 'Sviluppatore',
    creationDate: now(), isFromDeveloper: true, likes: 0, ...overrides,
  }
}

// Seeds a feedback as the server holds it (rules off), so the client-side checks run against it.
async function seed(data = feedback()) {
  await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'feedback', data.id), data))
}

test('submitFeedback: creates a new feedback with zero counts', async () => {
  const db = anon()
  await assertSucceeds(setDoc(doc(db, 'feedback', ID), feedback()))
})

test('submitFeedback: rejects a feedback that starts with votes or likes', async () => {
  await assertFails(setDoc(doc(anon(), 'feedback', ID), feedback({ votes: 5 })))
  await assertFails(setDoc(doc(anon(), 'feedback', ID), feedback({ likes: 1 })))
})

test('submitFeedback: rejects a document whose id differs from its path', async () => {
  await assertFails(setDoc(doc(anon(), 'feedback', ID), feedback({ id: 'altro' })))
})

test('submitFeedback: rejects a status other than pending at creation', async () => {
  await assertFails(setDoc(doc(anon(), 'feedback', ID), feedback({ status: 'completed' })))
})

test('submitFeedback: rejects extra fields and oversized text', async () => {
  await assertFails(setDoc(doc(anon(), 'feedback', ID), { ...feedback(), role: 'admin' }))
  await assertFails(setDoc(doc(anon(), 'feedback', ID), feedback({ description: 'x'.repeat(5001) })))
})

test('fetchFeedback: anyone can list the feedback, ordered by votes', async () => {
  await seed(feedback({ votes: 3 }))
  await assertSucceeds(getDocs(query(collection(anon(), 'feedback'))))
})

test('toggleVote: an update of the vote count is allowed', async () => {
  await seed()
  const db = anon()
  await assertSucceeds(runTransaction(db, async tx => {
    const snap = await tx.get(doc(db, 'feedback', ID))
    tx.update(doc(db, 'feedback', ID), { votes: snap.data().votes + 1 })
  }))
})

test('toggleVote: the vote document is created as the app writes it', async () => {
  await seed()
  const db = anon()
  const voteId = `uuid-utente_${ID}`
  await assertSucceeds(setDoc(doc(db, 'votes', voteId), { userId: 'uuid-utente', feedbackId: ID, createdAt: now() }))
})

test('toggleVote: a vote with the wrong id is rejected (one vote per user and feedback)', async () => {
  await assertFails(setDoc(doc(anon(), 'votes', 'qualcosa-altro'), { userId: 'uuid-utente', feedbackId: ID, createdAt: now() }))
})

test('toggleVote: removing a vote is allowed, changing one is not', async () => {
  await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'votes', `uuid-utente_${ID}`), { userId: 'uuid-utente', feedbackId: ID, createdAt: now() }))
  await assertSucceeds(deleteDoc(doc(anon(), 'votes', `uuid-utente_${ID}`)))
  await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'votes', `uuid-utente_${ID}`), { userId: 'uuid-utente', feedbackId: ID, createdAt: now() }))
  await assertFails(updateDoc(doc(anon(), 'votes', `uuid-utente_${ID}`), { feedbackId: 'altro' }))
})

test('toggleLike: a like document is created as the app writes it', async () => {
  await seed()
  await assertSucceeds(setDoc(doc(anon(), 'likes', `uuid-utente_${ID}`), { userId: 'uuid-utente', feedbackId: ID, createdAt: now() }))
})

test('submitReply: a developer reply can be added to the list', async () => {
  await seed()
  await assertSucceeds(updateDoc(doc(anon(), 'feedback', ID), { replies: arrayUnion(reply()) }))
})

test('submitReply: a list longer than 500 replies is rejected', async () => {
  await seed(feedback({ replies: Array.from({ length: 500 }, (_, i) => reply({ id: `R-${i}` })) }))
  await assertFails(updateDoc(doc(anon(), 'feedback', ID), { replies: arrayUnion(reply({ id: 'R-extra' })) }))
})

test('replies cannot be removed', async () => {
  await seed(feedback({ replies: [reply()] }))
  await assertFails(updateDoc(doc(anon(), 'feedback', ID), { replies: [] }))
})

test('the text of someone else\'s feedback cannot be changed', async () => {
  await seed()
  await assertFails(updateDoc(doc(anon(), 'feedback', ID), { title: 'Cambiato da altri' }))
  await assertFails(updateDoc(doc(anon(), 'feedback', ID), { authorName: 'Impostore' }))
})

test('moving to an account: the author can be set to your own account id, nobody else', async () => {
  await seed()
  const mine = env.authenticatedContext('uuid-nuovo').firestore()
  await assertSucceeds(updateDoc(doc(mine, 'feedback', ID), { authorId: 'uuid-nuovo' }))
  await seed()
  await assertFails(updateDoc(doc(anon(), 'feedback', ID), { authorId: 'uuid-nuovo' }))
  const other = env.authenticatedContext('uuid-altro').firestore()
  await assertFails(updateDoc(doc(other, 'feedback', ID), { authorId: 'uuid-nuovo' }))
})

test('moving to an account: the text still cannot be changed in the same write', async () => {
  await seed()
  const mine = env.authenticatedContext('uuid-nuovo').firestore()
  await assertFails(updateDoc(doc(mine, 'feedback', ID), { authorId: 'uuid-nuovo', title: 'Cambiato' }))
})

test('the status of a feedback cannot be changed from the app', async () => {
  await seed()
  await assertFails(updateDoc(doc(anon(), 'feedback', ID), { status: 'completed' }))
})

test('deleteFeedback: the batch removes the feedback with its votes and likes', async () => {
  await seed()
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'votes', `uuid-utente_${ID}`), { userId: 'uuid-utente', feedbackId: ID, createdAt: now() })
    await setDoc(doc(ctx.firestore(), 'likes', `uuid-altro_${ID}`), { userId: 'uuid-altro', feedbackId: ID, createdAt: now() })
  })
  const db = anon()
  const votes = await getDocs(query(collection(db, 'votes'), where('feedbackId', '==', ID)))
  const likes = await getDocs(query(collection(db, 'likes'), where('feedbackId', '==', ID)))
  assert.equal(votes.size, 1)
  assert.equal(likes.size, 1)
  const batch = writeBatch(db)
  votes.forEach(d => batch.delete(d.ref))
  likes.forEach(d => batch.delete(d.ref))
  batch.delete(doc(db, 'feedback', ID))
  await assertSucceeds(batch.commit())
})

test('app_updates: the app can read the news', async () => {
  await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'app_updates', 'n1'), { title: 'Novità', type: 'feature' }))
  await assertSucceeds(getDoc(doc(anon(), 'app_updates', 'n1')))
})

test('app_updates: nobody can write the news from a client', async () => {
  await assertFails(setDoc(doc(anon(), 'app_updates', 'n2'), { title: 'Finto', type: 'feature' }))
})

test('users, tasks, rewards, analytics: no client access at all', async () => {
  const db = anon()
  await assertFails(setDoc(doc(db, 'users', 'uuid-utente', 'tasks', 't1'), { name: 'x' }))
  await assertFails(getDoc(doc(db, 'users', 'uuid-utente', 'tasks', 't1')))
  await assertFails(setDoc(doc(db, 'rewards', 'r1'), { name: 'x' }))
  await assertFails(setDoc(doc(db, 'analytics', 'e1'), { name: 'x' }))
  await assertFails(setDoc(doc(db, 'pomodoro_sessions', 'p1'), { name: 'x' }))
})

test('feedback_replies and reply_likes: not used by the app, so closed', async () => {
  await assertFails(setDoc(doc(anon(), 'feedback_replies', 'x'), { a: 1 }))
  await assertFails(setDoc(doc(anon(), 'reply_likes', 'x'), { a: 1 }))
})
