import '../../lib/fomantic-ui-2.7.1/semantic.css';
import '../../lib/fomantic-ui-2.7.1/semantic.js';
import $ from 'jquery';

let body = $('body');

let modalHtml = `
<div class='ui-container'>

  <div class='ui grid toolbar'>
    <div class='column'>

      <div class='row'>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
      </div>

      <div class='row'>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
      </div>

      <div class='row'>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
        <button class="ui icon button">
          <i class="cloud icon"></i>
        </button>
      </div>
      
    </div>
  </div>
</div>
`;

//body.append(modalHtml);

//$('.ui.modal').modal();