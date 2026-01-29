# frozen_string_literal: true

module Homebrew
  module Cmd
    class GetSource < AbstractCommand
      cmd_args do
        description <<~EOS
          Fetch and patch source for formulae.
        EOS
        switch '-P', '--no-patch',
               description: "Don't patch the formulae."
        flag '--out=',
             description: 'Location in which to put formulae.'
        
        named_args :formula, min: 1
      end

      def run
        out_dir = Pathname(args.out || '.').realpath
        out_dir.mkdir unless out_dir.exist? || args.named.length == 1
        args.named.each do |formula|
          form = Formulary.factory(formula)
          form.brew do
            form.patch unless args.no_patch?
            FileUtils.mv(Dir.pwd, out_dir.to_str)
          end
        end
      end
    end
  end
end
