import React, { useState, useEffect } from 'react';
import styles from './Chat.module.css';

const Chat = ({ messages, send }) => {

  const handleSubmit = (e) => {
    e.preventDefault();
    send(e.target.message.value);
    e.target.message.value = "";
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.message_list}>
        { Object.entries(messages).map(([i, msg]) => (
            <div className={styles.message} key={i}>
              <p>{msg.from}: {msg.msg}</p>
            </div>
          ))
        }
      </div>
      <form className={styles.form} onSubmit={e => handleSubmit(e)}>
        <input name="message" type="text" placeholder="..." />
        <button type="submit">Send</button>
      </form>
    </div>
  );
};

export default Chat;