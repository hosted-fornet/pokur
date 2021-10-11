import React, { useReducer, useEffect, useState } from "react";
import { ChallengeForm, ChallengeList, Game } from './components';
import _ from "lodash";
import Urbit from "@urbit/http-api";

const createApi = (host, code) =>
  _.memoize(
    () => {
      const urb = new Urbit(host, code);
      urb.ship = window.ship;
      try {
        urb.connect();
      } catch (err) {
        console.log(err);
      }
      urb.onError = (message) => console.log(message);
      return urb;
    }
  );

function messageReducer(state, newMessage) {
  if (state[0] != newMessage) {
    return [newMessage, ...state];
  } else {
    return state;
  }
}

const App = () => {
  const [loggedIn, setLoggedIn] = useState();
  const [urb, setUrb] = useState();
  const [sub, setSub] = useState();
  const [sentChallenge, setSentChallenge] = useState(false);
  const [inGame, setInGame] = useState(false);
  const [spectating, setSpectating] = useState(false);
  const [gameState, setGameState] = useState();
  const [myBet, setMyBet] = useState();
  const [gameMessages, setGameMessages] = useReducer(messageReducer, ["", "", "", "", ""]);

  useEffect(() => {
    if (localStorage.getItem("host") && localStorage.getItem("code")) {
      console.log("got host/code from cookie");
      setLoggedIn(true);
      const _urb = createApi(
        localStorage.getItem("host"),
        localStorage.getItem("code")
      );
      setUrb(_urb);
      return () => {};
    }
  }, []);

  // subscribe to /game path to recieve game updates
  useEffect(() => {
    if (!urb || sub) return;
    urb
      .subscribe({
        app: "pokur",
        path: "/game",
        event: updateGameState,
        err: console.log,
        quit: console.log,
      })
      .then((subscriptionId) => {
        setSub(subscriptionId);
      });
  }, [urb]);

  const login = (host, code) => {
    localStorage.setItem("host", host);
    localStorage.setItem("code", code);
    const _urb = createApi(host, code);
    setUrb(_urb);
    setLoggedIn(true);
    return () => {};
  };

  function updateGameState(newGameState) {
    if (newGameState.in_game) {
      setGameState(newGameState);
      setGameMessages(newGameState.update_message);
      // localStorage.setItem("gameTimer", newGameState.time_limit_seconds);
      setMyBet(
        newGameState.current_bet > 0 
              ? newGameState.current_bet + newGameState.last_bet
              : newGameState.min_bet
      )
      if (newGameState.players.includes(window.ship)) {
        setSpectating(false);
      } else {
        setSpectating(true);
      }
      setInGame(true);
    } else {
      setInGame(false);
    }
  };

  return (
    <>
      <header>
        <p>Pokur Beta</p>
      </header>
      {loggedIn 
      ? <></>
      : <div id="login"><pre>Login:</pre>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          const host = e.target.host.value;
          const code = e.target.code.value;
          login(host, code);
        }}
      >
        <input
          type="host"
          name="host"
          placeholder={
            loggedIn ? localStorage.getItem("host") : "Host"
          }
        />
        <br />
        <input
          type="code"
          name="code"
          placeholder={
            loggedIn ? localStorage.getItem("code") : "Code"
          }
        />
        <br />
        <input type="submit" value="Login" />
      </form></div> }
      {inGame ? <Game 
                  urb={urb}
                  game={gameState} 
                  spectating={spectating}
                  myBet={myBet} 
                  setMyBet={setMyBet}
                  gameMessages={gameMessages}
                />
              : !sentChallenge 
                 ? <div>
                     <ChallengeForm 
                       urb={urb}
                       sentChallenge={sentChallenge}
                       setSentChallenge={setSentChallenge} 
                     />
                     <ChallengeList 
                       urb={urb}
                       setSpectating={setSpectating}
                       setSentChallenge={setSentChallenge} 
                     />
                   </div>
                 : <div>
                    <ChallengeList 
                       urb={urb}
                       setSentChallenge={setSentChallenge}  
                     />
                   </div>}
    </>
  );
};

export default App;
