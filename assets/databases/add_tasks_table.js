// File: add_tasks_table.js

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const { v4: uuidv4 } = require('uuid'); // for unique task IDs

// Adjust this path if your DB is elsewhere
const DB_PATH = path.join(__dirname, 'spanish_app.db');

function clearTasksTable(db) {
  return new Promise((resolve, reject) => {
    db.run('DELETE FROM tasks;', (err) => {
      if (err) return reject(err);
      console.log('🧹 Cleared existing tasks from "tasks" table');
      resolve();
    });
  });
}


function createTasksTable(db) {
  return new Promise((resolve, reject) => {
    const createSQL = `
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        locale TEXT NOT NULL,
        task_type TEXT NOT NULL
        
      );
    `;
    db.run(createSQL, (err) => {
      if (err) return reject(err);
      console.log('✅ Created (or verified) table "tasks"');
      resolve();
    });
  });
}

function insertTasks(db) {
  return new Promise((resolve, reject) => {


    const tasks = [
          {
            id: uuidv4(),
            description: 'Finish this sentence logically, using the model sentence as context.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Paraphrase the given sentence in your own words.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Ask a follow-up question based on the content of the sentence.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Answer your own question related to the sentence’s context.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Transform the sentence into its negative form.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Change the tense of the sentence (e.g., present → future).',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Convert the statement into a yes/no or wh-question.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Summarize the meaning of the sentence in one shorter sentence.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Expand the sentence by adding two extra details (time, place, or reason).',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Create a contrasting sentence using “but” or “however”.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'List three synonyms or collocates related to the key word in the sentence.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Write a follow-up sentence that logically continues the scenario.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Explain the meaning of one word from the sentence in a 15-second mini-lesson.',
            locale: 'en',
            task_type: 'sentence',
          },
          {
            id: uuidv4(),
            description: 'Pose three rapid-fire interview questions someone might ask after hearing the sentence.',
            locale: 'en',
            task_type: 'sentence',
          },
            {
              id: uuidv4(),
              description: 'Pose a brief question that frames the target word (“What’s your favorite [word] activity?”).',
              locale: 'en',
              task_type: 'word',
            },
            {
              id: uuidv4(),
              description: 'State a prompt involving the word (e.g., “Is it better to [word] alone or in a group?”).',
              locale: 'en',
              task_type: 'word',
            },
            {
              id: uuidv4(),
              description: 'List three common collocates (words that often pair) for today’s word.',
              locale: 'en',
              task_type: 'word',
            },
            {
              id: uuidv4(),
              description: 'User pretends to teach the word to a friend: records a 20-second mini-lesson defining the word, giving an example, and pronouncing it.',
              locale: 'en',
              task_type: 'word',
            },
            {
              id: uuidv4(),
              description: 'At day’s end, prompt “How did you use today’s word outside the app?” User records a 60-second personal reflection, cementing real-world relevance.',
              locale: 'en',
              task_type: 'word',
            },
            {
                id: uuidv4(),
                description: 'Завершите это предложение логично, используя модельное предложение в качестве контекста.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Перефразируйте данное предложение своими словами.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Задайте уточняющий вопрос, основываясь на содержании предложения.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Ответьте на собственный вопрос, связанный с контекстом предложения.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Преобразуйте предложение в отрицательную форму.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Измените время предложения (например, настоящее → будущее).',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Преобразуйте утверждение в вопрос типа «да/нет» или вопросительное слово.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Сократите смысл предложения, изложив его в одном более коротком предложении.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Расширьте предложение, добавив две дополнительные детали (время, место или причину).',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Создайте противопоставляющее предложение, используя «но» или «однако».',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Перечислите три синонима или словосочетания, связанные с ключевым словом в предложении.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Напишите следующее предложение, которое логически продолжает ситуацию.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Объясните значение одного слова из предложения в мини-уроке длительностью 15 секунд.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Задайте три быстрых вопроса-интервью, которые кто-то мог бы задать после того, как услышит предложение.',
                locale: 'ru',
                task_type: 'sentence',
              },
              {
                id: uuidv4(),
                description: 'Задайте краткий вопрос, в котором используется целевое слово («Какая у вас любимая активность с [слово]?»).',
                locale: 'ru',
                task_type: 'word',
              },
              {
                id: uuidv4(),
                description: 'Дайте задание с использованием слова (например: «Что лучше – [слово] одному или в группе?»).',
                locale: 'ru',
                task_type: 'word',
              },
              {
                id: uuidv4(),
                description: 'Назовите три распространённых словосочетания (слова, часто сочетающиеся) для сегодняшнего слова.',
                locale: 'ru',
                task_type: 'word',
              },
              {
                id: uuidv4(),
                description: 'Пользователь притворяется, что преподаёт слово другу: записывает мини-урок длительностью 20 секунд с определением слова, примером и произношением.',
                locale: 'ru',
                task_type: 'word',
              },
              {
                id: uuidv4(),
                description: 'В конце дня предложите «Как вы использовали сегодняшнее слово вне приложения?» Пользователь записывает 60-секундное личное размышление, закрепляя актуальность в реальной жизни.',
                locale: 'ru',
                task_type: 'word',
              },
              {
                  id: uuidv4(),
                  description: 'Termina esta oración de forma lógica, usando la oración modelo como contexto.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Parafrasea la oración dada con tus propias palabras.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Haz una pregunta de seguimiento basada en el contenido de la oración.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Responde tu propia pregunta relacionada con el contexto de la oración.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Transforma la oración a su forma negativa.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Cambia el tiempo de la oración (por ejemplo, presente → futuro).',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Convierte la afirmación en una pregunta de sí/no o en una pregunta con pronombre interrogativo.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Resume el significado de la oración en una sola oración más breve.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Expande la oración añadiendo dos detalles extra (hora, lugar o motivo).',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Crea una oración de contraste usando “pero” o “sin embargo”.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Enumera tres sinónimos o colocaciones relacionadas con la palabra clave en la oración.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Escribe una oración de seguimiento que continúe lógicamente el escenario.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Explica el significado de una palabra de la oración en una mini- lección de 15 segundos.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Formula tres preguntas rápidas tipo entrevista que alguien podría hacer después de escuchar la oración.',
                  locale: 'es',
                  task_type: 'sentence',
                },
                {
                  id: uuidv4(),
                  description: 'Formula una breve pregunta que enmarque la palabra objetivo (“¿Cuál es tu actividad favorita de [word]?”).',
                  locale: 'es',
                  task_type: 'word',
                },
                {
                  id: uuidv4(),
                  description: 'Presenta un enunciado que involucre la palabra (por ejemplo, “¿Es mejor [word] solo o en grupo?”).',
                  locale: 'es',
                  task_type: 'word',
                },
                {
                  id: uuidv4(),
                  description: 'Enumera tres colocaciones comunes (palabras que suelen ir juntas) para la palabra de hoy.',
                  locale: 'es',
                  task_type: 'word',
                },
                {
                  id: uuidv4(),
                  description: 'El usuario finge enseñar la palabra a un amigo: graba una mini lección de 20 segundos definiendo la palabra, dando un ejemplo y pronunciándola.',
                  locale: 'es',
                  task_type: 'word',
                },
                {
                  id: uuidv4(),
                  description: 'Al final del día, pregunta “¿Cómo usaste la palabra de hoy fuera de la aplicación?” El usuario graba una reflexión personal de 60 segundos, consolidando la relevancia en el mundo real.',
                  locale: 'es',
                  task_type: 'word',
                }
        ];

    const insertSQL = `
          INSERT INTO tasks (
            id,
            description,
            locale,
            task_type
          ) VALUES (?, ?, ?, ?);
        `;
        const stmt = db.prepare(insertSQL);

        for (const task of tasks) {
          stmt.run(
            task.id,
            task.description,
            task.locale,
            task.task_type,
            (err) => {
              if (err) {
                console.error('❌ Failed to insert task:', task.id, err.message);
              }
            }
          );
        }

        stmt.finalize((err) => {
          if (err) return reject(err);
          console.log(`✅ Inserted ${tasks.length} tasks into table "tasks"`);
          resolve();
        });
      });
    }

async function main() {
  const db = new sqlite3.Database(DB_PATH, sqlite3.OPEN_READWRITE, (err) => {
    if (err) {
      console.error(`❌ Unable to open database at ${DB_PATH}:`, err.message);
      process.exit(1);
    }
  });

  try {
    await new Promise((resolve) => db.serialize(resolve)); // Ensures serialize runs once
    await createTasksTable(db);
    await clearTasksTable(db);   // Clear ONCE
    await insertTasks(db);       // Fill ONCE
    console.log('🎉 All done.');
  } catch (e) {
    console.error('❌ Error:', e);
  } finally {
    db.close();
  }
}


main();
