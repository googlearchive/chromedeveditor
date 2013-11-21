var errutils = {
  // Indicates an unexpected error in the file system.
  FILE_IO_ERROR: 0,
  FILE_IO_ERROR_MSG: 'Unexpected File I/O error',
  // Indicates an unexpected ajax error when trying to make a request
  AJAX_ERROR: 1,
  AJAX_ERROR_MSG: 'Unexpected ajax error',

  // trying to clone into a non-empty directory
  CLONE_DIR_NOT_EMPTY: 2,
  CLONE_DIR_NOT_EMPTY_MSG: 'The target directory contains files',
  // No .git directory
  CLONE_DIR_NOT_INTIALIZED: 3,
  CLONE_DIR_NOT_INTIALIZED_MSG: 'The target directory hasn\'t been initialized.',
  // .git directory already contains objects
  CLONE_GIT_DIR_IN_USE: 4,
  CLONE_GIT_DIR_IN_USE_MSG: 'The target directory contains a .git directory already in use.',
  // No branch found with the name given
  REMOTE_BRANCH_NOT_FOUND: 5,
  REMOTE_BRANCH_NOT_FOUND_MSG: 'Can\'t find the branch name in the remote repository',

  // only supports fast forward merging at the moment.
  PULL_NON_FAST_FORWARD: 6,
  PULL_NON_FAST_FORWARD_MSG: 'Pulling from the remote repo requires a merge.',
  // Branch is up to date
  PULL_UP_TO_DATE: 7,
  PULL_UP_TO_DATE_MSG: 'Everything is up to date',


  UNCOMMITTED_CHANGES: 11,
  UNCOMMITTED_CHANGES_MSG: 'There are changes in the working directory that haven\'t been committed',

  // Nothing to commit
  COMMIT_NO_CHANGES: 8,
  COMMIT_NO_CHANGES_MSG: 'No changes to commit',

  // The remote repo and the local repo share the same head.
  PUSH_NO_CHANGES: 9,
  PUSH_NO_CHANGES_MSG: 'No new commits to push to the repository',

  PUSH_NO_REMOTE: 16,
  PUSH_NO_REMOTE_MSG: 'No remote to push to',

  // Need to merge remote changes first.
  PUSH_NON_FAST_FORWARD: 10,
  PUSH_NON_FAST_FORWARD_MSG: 'The remote repo has new commits on your current branch. You need to merge them first.',

  BRANCH_ALREADY_EXISTS: 14,
  BRANCH_ALREADY_EXISTS_MSG: 'A local branch with that name already exists',

  BRANCH_NAME_NOT_VALID: 12,
  BRANCH_NAME_NOT_VALID_MSG: 'The branch name is not valid.',

  CHECKOUT_BRANCH_NO_EXISTS: 15,
  CHECKOUT_BRANCH_NO_EXISTS_MSG: 'No local branch with that name exists',

  // unexpected problem retrieving objects
  OBJECT_STORE_CORRUPTED: 200,
  OBJECT_STORE_CORRUPTED_MSG: 'Git object store may be corrupted',

  HTTP_AUTH_ERROR: 201,
  HTTP_AUTH_ERROR_MSG: 'Http authentication failed',

  UNPACK_ERROR: 202,
  UNPACK_ERROR_MSG: 'The remote git server wasn\'t able to understand the push request.',


  fileErrorFunc : function(onError){
    if (!onError){
  return function(){};
    }
    return function(e) {
  var msg = errors.getFileErrorMsg(e);
  onError({type : errors.FILE_IO_ERROR, msg: msg, fe: e.code});
    }
  },

  ajaxErrorFunc : function(onError){
    return function(xhr){
  var url = this.url,
    reqType = this.type;

  var httpErr;
  if (xhr.status == 401){
    var auth = xhr.getResponseHeader('WWW-Authenticate');
    httpErr = {type: errors.HTTP_AUTH_ERROR, msg: errors.HTTP_AUTH_ERROR_MSG, auth: auth};
  }
  else{
    httpErr = {type: errors.AJAX_ERROR, url: url, reqType: reqType, statusText: xhr.statusText, status: xhr.status, msg: "Http error with status code: " + xhr.status + ' and status text: "' + xhr.statusText + '"'};
  }
  onError(httpErr);
    }
  },

  getFileErrorMsg: function(e) {
    var msg = '';

  switch (e.code) {
    case FileError.QUOTA_EXCEEDED_ERR:
      msg = 'QUOTA_EXCEEDED_ERR';
      break;
    case FileError.NOT_FOUND_ERR:
      msg = 'NOT_FOUND_ERR';
      break;
    case FileError.SECURITY_ERR:
      msg = 'SECURITY_ERR';
      break;
    case FileError.INVALID_MODIFICATION_ERR:
      msg = 'INVALID_MODIFICATION_ERR';
      break;
    case FileError.INVALID_STATE_ERR:
      msg = 'INVALID_STATE_ERR';
      break;
    case FileError.ABORT_ERR:
      msg = 'ABORT_ERR';
      break;
    case FileError.ENCODING_ERR:
      msg = 'ENCODING_ERR';
      break;
    case FileError.NOT_READABLE_ERR:
      msg = 'NOT_READABLE_ERR';
      break;
    case FileError.NO_MODIFICATION_ALLOWED_ERR:
      msg = 'NO_MODIFICATION_ALLOWED_ERR';
      break;
    case FileError.PATH_EXISTS_ERR:
      msg = 'PATH_EXISTS_ERR';
      break;
    case FileError.SYNTAX_ERR:
      msg = 'SYNTAX_ERR';
      break;
    case FileError.TYPE_MISMATCH_ERR:
      msg = 'TYPE_MISMATCH_ERR';
      break;
    default:
      msg = 'Unknown Error ' + e.code;
      break;
    };
  },
  errorHandler: function(e) {
    msg = utils.getFileErrorMsg(e);
    console.log('Error: ' + msg);
  }
};
