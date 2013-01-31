CodeMirror.defineMode('ats', function() {

  var words = {
    'true': 'atom',
    'false': 'atom',
    'let': 'keyword',
    'in': 'keyword',
    'of': 'keyword',
    'and': 'keyword',
    'if': 'keyword',
    'then': 'keyword',
    'else': 'keyword',
    'for': 'keyword',
    'while': 'keyword',
    'extern': 'keyword',
    'fun': 'keyword',
    'fn': 'keyword',
    'implement': 'keyword',
    'function': 'keyword',
    'prval': 'keyword',
    'prval+': 'keyword',
    'prval-': 'keyword',
    'val': 'keyword',
    'val+': 'keyword',
    'val-': 'keyword',
    'type': 'keyword',
    't@ype': 'keyword',
    'abstype': 'keyword',
    'abst@ype': 'keyword',
    'absviewt@ype': 'keyword',
    'absview': 'keyword',
    'absprop': 'keyword',
    'datatype': 'keyword',
    'dataviewtype': 'keyword',
    'dataview': 'keyword',
    'macdef': 'keyword',
    'stadef' : 'keyword',
    'viewt@ype': 'keyword',
    'viewt@ype+': 'keyword',
    'case': 'keyword',
    'case+': 'keyword',
    'case-': 'keyword',
    'where': 'keyword',
    'try': 'keyword',
    'raise': 'keyword',
    'begin': 'keyword',
    'end': 'keyword',
    'exit': 'builtin',
    'println': 'builtin',
    'print': 'builtin',
    'print_newline': 'builtin'
  };
  
  function tokenBase(stream, state) {
    var ch = stream.next();

    if (ch === '"') {
      state.tokenize = tokenString;
      return state.tokenize(stream, state);
    }
    if (ch === '(') {
      if (stream.eat('*')) {
        state.commentLevel++;
        state.tokenize = tokenComment;
        return state.tokenize(stream, state);
      }
    }
    if (ch === '~') {
      stream.eatWhile(/\w/);
      return 'variable-2';
    }
    if (ch === '`') {
      stream.eatWhile(/\w/);
      return 'quote';
    }
    if (/\d/.test(ch)) {
      stream.eatWhile(/[\d]/);
      if (stream.eat('.')) {
        stream.eatWhile(/[\d]/);
      }
      return 'number';
    }
    if ( /[+\-*&%=<>!?|]/.test(ch)) {
      return 'operator';
    }
    stream.eatWhile(/\w/);
    var cur = stream.current();
    return words[cur] || 'variable';
  }

  function tokenString(stream, state) {
    var next, end = false, escaped = false;
    while ((next = stream.next()) != null) {
      if (next === '"' && !escaped) {
        end = true;
        break;
      }
      escaped = !escaped && next === '\\';
    }
    if (end && !escaped) {
      state.tokenize = tokenBase;
    }
    return 'string';
  };

  function tokenComment(stream, state) {
    var prev, next;
    while(state.commentLevel > 0 && (next = stream.next()) != null) {
      if (prev === '(' && next === '*') state.commentLevel++;
      if (prev === '*' && next === ')') state.commentLevel--;
      prev = next;
    }
    if (state.commentLevel <= 0) {
      state.tokenize = tokenBase;
    }
    return 'comment';
  }

  return {
    startState: function() {return {tokenize: tokenBase, commentLevel: 0};},
    token: function(stream, state) {
      if (stream.eatSpace()) return null;
      return state.tokenize(stream, state);
    }
  };
});
  
CodeMirror.defineMIME('text/x-ats', 'ats');