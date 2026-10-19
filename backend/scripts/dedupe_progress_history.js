// Removes duplicated BMI / calorie values from progress history.
//
// Older versions of POST /api/progress copied the other tracker's latest values
// into every new entry (saving BMI also re-saved the last calories, and the
// other way round). That made old or reset values reappear and showed every
// value twice in the history and charts.
//
// For each entry, a tracker's values are treated as a copy when they are the
// same as the previous entry's values and its update timestamp is also the
// same as the previous entry's (a real new entry always gets a new timestamp).
// Copies are removed. Entries left with no values are deleted (their reset audit trail is
// moved to the previous entry), except the latest one, which holds the timers.
//
// Usage (from backend/):
//   node scripts/dedupe_progress_history.js            -> dry run, shows changes
//   node scripts/dedupe_progress_history.js --apply    -> writes the changes
//   add --user <userId> to limit it to one member
require('dotenv').config();
const mongoose = require('mongoose');
const Progress = require('../models/Progress');

const APPLY = process.argv.includes('--apply');
const userArg = process.argv.indexOf('--user');
const ONLY_USER = userArg !== -1 ? process.argv[userArg + 1] : null;

const TRACKERS = {
  bmi: { fields: ['bmi'], stamp: 'lastBmiUpdate' },
  calories: { fields: ['caloriesIntake', 'calorieDeficit'], stamp: 'lastCaloriesUpdate' }
};
const hasValue = (v) => v !== undefined && v !== null;
const sameValues = (a, b, fields) => fields.every((f) => (hasValue(a[f]) ? a[f] : null) === (hasValue(b[f]) ? b[f] : null));
// A value entered in this entry gets a new update timestamp; a copied value
// keeps the previous entry's timestamp (or null after a reset).
const stampTime = (d, stamp) => (hasValue(d[stamp]) ? new Date(d[stamp]).getTime() : null);
const enteredHere = (doc, prev, stamp) => stampTime(doc, stamp) !== stampTime(prev, stamp);
const show = (d) => `bmi=${d.bmi ?? '-'} cal=${d.caloriesIntake ?? '-'} def=${d.calorieDeficit ?? '-'}`;

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log(`Connected to MongoDB (${APPLY ? 'APPLY' : 'DRY RUN'})`);

  const userIds = ONLY_USER ? [ONLY_USER] : await Progress.distinct('user');
  let changed = 0;
  let deleted = 0;

  for (const userId of userIds) {
    const docs = await Progress.find({ user: userId }).sort({ createdAt: 1 }).lean();
    for (let i = 1; i < docs.length; i += 1) {
      const doc = docs[i];
      const prev = docs[i - 1]; // original values, before any change in this run
      const $unset = {};

      for (const { fields, stamp } of Object.values(TRACKERS)) {
        const present = fields.some((f) => hasValue(doc[f]));
        if (present && !enteredHere(doc, prev, stamp) && sameValues(doc, prev, fields)) {
          for (const f of fields) $unset[f] = 1;
        }
      }
      if (!Object.keys($unset).length) continue;

      const left = Object.values(TRACKERS).some(({ fields }) => fields.some((f) => hasValue(doc[f]) && !$unset[f]));
      const isLatest = i === docs.length - 1;

      if (!left && !isLatest) {
        console.log(`[${userId}] delete ${doc._id} (${doc.createdAt.toISOString()}) ${show(doc)} - only copied values`);
        deleted += 1;
        if (APPLY) {
          if (doc.cooldownResets && doc.cooldownResets.length) {
            // Move the audit trail to the closest earlier entry that still exists
            const target = await Progress.findOne({ user: userId, createdAt: { $lt: doc.createdAt } }).sort({ createdAt: -1 });
            if (target) await Progress.updateOne({ _id: target._id }, { $push: { cooldownResets: { $each: doc.cooldownResets } } });
          }
          await Progress.deleteOne({ _id: doc._id });
        }
      } else {
        console.log(`[${userId}] clean  ${doc._id} (${doc.createdAt.toISOString()}) ${show(doc)} - remove copied ${Object.keys($unset).join(', ')}`);
        changed += 1;
        if (APPLY) await Progress.updateOne({ _id: doc._id }, { $unset });
      }
    }
  }

  console.log(`\n${APPLY ? 'Done' : 'Dry run'}: ${changed} entries cleaned, ${deleted} entries deleted.`);
  if (!APPLY) console.log('Run again with --apply to save these changes.');
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
